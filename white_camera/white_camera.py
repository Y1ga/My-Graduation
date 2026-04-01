"""
LED Serial + ZWO ASI Camera Control
串口控制16路LED PWM ＋ ZWO相机实时预览
依赖: pip install pyserial zwoasi numpy Pillow opencv-python
ZWO ASI SDK: 需设置环境变量 ZWO_ASI_LIB 指向 libASICamera2.so/.dll
"""

import os
import re
import sys
import time
import threading
import tkinter as tk
from tkinter import ttk, messagebox, filedialog
from dataclasses import dataclass, field
from typing import Optional

import numpy as np
from PIL import Image, ImageTk

import serial
import serial.tools.list_ports

try:
    import zwoasi as asi

    _ASI_LIB = os.getenv("ZWO_ASI_LIB")
    if _ASI_LIB:
        asi.init(_ASI_LIB)
    else:
        # Windows 常见路径尝试
        for p in [
            "ASICamera2.dll",
            "./lib/ASICamera2.dll",
            "/usr/lib/libASICamera2.so",
            "/usr/local/lib/libASICamera2.so",
        ]:
            if os.path.exists(p):
                asi.init(p)
                break
    ASI_AVAILABLE = True
except Exception:
    ASI_AVAILABLE = False


# ═══════════════════════════════════════════════════════
#  配置常量
# ═══════════════════════════════════════════════════════

NUM_LEDS = 16
DEFAULT_BRIGHTNESS = 100
NEXT_LED_CYCLE = list(range(16))  # LED1~LED16 (0-based: 0~15)

# 相机默认参数
DEFAULT_EXPOSURE_US = 10000  # 10ms
DEFAULT_GAIN = 0
DEFAULT_IMG_TYPE = "RGB24"
DEFAULT_WB_R = 52
DEFAULT_WB_B = 95

# 默认 ROI (ASI 585MC: 3840×2160)
DEFAULT_ROI_X = 900
DEFAULT_ROI_Y = 200
DEFAULT_ROI_W = 1400
DEFAULT_ROI_H = 1800

# 保存文件前缀
SAVE_PREFIX = "Violet"
DEFAULT_SAVE_DIR = "./data"

# LED8 对应的 0-based index (用于判断是否保存 RGB)
LED8_INDEX = 7

IMG_TYPE_MAP = {
    "RAW8": asi.ASI_IMG_RAW8 if ASI_AVAILABLE else 0,
    "RAW16": asi.ASI_IMG_RAW16 if ASI_AVAILABLE else 1,
    "RGB24": asi.ASI_IMG_RGB24 if ASI_AVAILABLE else 2,
    "Y8": asi.ASI_IMG_Y8 if ASI_AVAILABLE else 3,
}


# ═══════════════════════════════════════════════════════
#  LED 数据模型
# ═══════════════════════════════════════════════════════


@dataclass
class LedState:
    pwm: bytearray = field(default_factory=lambda: bytearray(NUM_LEDS))
    selected_index: int = 1
    selected_value: int = 0

    def clear(self):
        for i in range(NUM_LEDS):
            self.pwm[i] = 0

    def set_channel(self, index: int, value: int):
        self.pwm[index] = max(0, min(100, value))

    def to_bytes(self) -> bytes:
        return bytes(self.pwm)


# ═══════════════════════════════════════════════════════
#  串口管理器
# ═══════════════════════════════════════════════════════


@dataclass
class SerialConfig:
    port: str = ""
    baudrate: int = 460800
    bytesize: int = 8
    stopbits: str = "1"
    parity: str = "None"

    _STOPBITS = {
        "1": serial.STOPBITS_ONE,
        "1.5": serial.STOPBITS_ONE_POINT_FIVE,
        "2": serial.STOPBITS_TWO,
    }
    _PARITY = {
        "None": serial.PARITY_NONE,
        "Odd": serial.PARITY_ODD,
        "Even": serial.PARITY_EVEN,
    }

    def open(self) -> serial.Serial:
        return serial.Serial(
            port=self.port,
            baudrate=self.baudrate,
            bytesize=self.bytesize,
            stopbits=self._STOPBITS.get(self.stopbits, serial.STOPBITS_ONE),
            parity=self._PARITY.get(self.parity, serial.PARITY_NONE),
            timeout=0.1,
            write_timeout=1,
            dsrdtr=False,
            rtscts=False,
            xonxoff=False,
        )


class SerialManager:
    def __init__(self, on_frame=None):
        self._port: Optional[serial.Serial] = None
        self._recv_running = False
        self._on_frame = on_frame
        self._lock = threading.Lock()

    @property
    def is_open(self) -> bool:
        return self._port is not None and self._port.is_open

    def open(self, config: SerialConfig):
        self.close()
        self._port = config.open()
        time.sleep(0.2)
        self._port.reset_input_buffer()
        self._port.reset_output_buffer()
        self._recv_running = True
        threading.Thread(target=self._recv_loop, daemon=True).start()

    def close(self):
        self._recv_running = False
        with self._lock:
            if self._port and self._port.is_open:
                self._port.close()
            self._port = None

    def send(self, data: bytes):
        with self._lock:
            if self.is_open:
                self._port.write(data)
                self._port.flush()

    def _recv_loop(self):
        buf = bytearray()
        while self._recv_running and self.is_open:
            try:
                with self._lock:
                    if not self.is_open:
                        break
                    chunk = self._port.read(256)
                if chunk:
                    buf.extend(chunk)
                    while b"\r\n" in buf:
                        end = buf.index(b"\r\n") + 2
                        if self._on_frame:
                            self._on_frame(bytes(buf[:end]))
                        buf = buf[end:]
                elif buf:
                    if self._on_frame:
                        self._on_frame(bytes(buf))
                    buf.clear()
            except Exception:
                break


# ═══════════════════════════════════════════════════════
#  ZWO 相机管理器
# ═══════════════════════════════════════════════════════


class CameraManager:
    """封装 ZWO ASI 相机操作，与 UI 解耦"""

    def __init__(self):
        self.camera = None
        self.camera_info = None
        self._streaming = False
        self._stream_thread: Optional[threading.Thread] = None
        self._last_frame: Optional[np.ndarray] = None  # 缓存最新帧用于保存
        self._current_img_type: str = DEFAULT_IMG_TYPE
        self.on_frame = None  # callback(np.ndarray)  主线程外调用
        self.on_status = None  # callback(str)

    @property
    def is_open(self) -> bool:
        return self.camera is not None

    @property
    def is_streaming(self) -> bool:
        return self._streaming

    def scan(self) -> list[str]:
        if not ASI_AVAILABLE:
            return []
        return asi.list_cameras()

    def open(self, index: int = 0):
        if not ASI_AVAILABLE:
            raise RuntimeError("ZWO ASI SDK 未加载，请设置 ZWO_ASI_LIB 环境变量")
        self.close()
        self.camera = asi.Camera(index)
        self.camera_info = self.camera.get_camera_property()
        # 设置默认参数
        self.camera.set_control_value(
            asi.ASI_BANDWIDTHOVERLOAD,
            self.camera.get_controls()["BandWidth"]["MinValue"],
        )
        self.camera.disable_dark_subtract()
        self.set_gain(DEFAULT_GAIN)
        self.set_exposure(DEFAULT_EXPOSURE_US)
        self.set_image_type(DEFAULT_IMG_TYPE)
        # 白平衡
        self.camera.set_control_value(asi.ASI_WB_R, DEFAULT_WB_R)
        self.camera.set_control_value(asi.ASI_WB_B, DEFAULT_WB_B)

    def close(self):
        self.stop_video()
        if self.camera:
            try:
                self.camera.close()
            except Exception:
                pass
        self.camera = None
        self.camera_info = None

    # ── 参数设置 ──

    def set_exposure(self, us: int):
        if self.camera:
            self.camera.set_control_value(asi.ASI_EXPOSURE, us)

    def get_exposure(self) -> int:
        if self.camera:
            return self.camera.get_control_value(asi.ASI_EXPOSURE)[0]
        return 0

    def set_gain(self, gain: int):
        if self.camera:
            self.camera.set_control_value(asi.ASI_GAIN, gain)

    def set_image_type(self, type_str: str):
        if self.camera and type_str in IMG_TYPE_MAP:
            self.camera.set_image_type(IMG_TYPE_MAP[type_str])
            self._current_img_type = type_str

    def get_max_size(self) -> tuple[int, int]:
        if self.camera_info:
            return self.camera_info["MaxWidth"], self.camera_info["MaxHeight"]
        return 0, 0

    def get_supported_bins(self) -> list[int]:
        if self.camera_info:
            return self.camera_info["SupportedBins"]
        return [1]

    def set_roi(
        self, start_x: int, start_y: int, width: int, height: int, bins: int = 1
    ):
        if not self.camera:
            return
        # ASI SDK 要求: width % 8 == 0, height % 2 == 0
        width = width - (width % 8)
        height = height - (height % 2)
        was_streaming = self._streaming
        if was_streaming:
            self.stop_video()
        self.camera.set_roi(start_x, start_y, width, height, bins)
        if was_streaming:
            self.start_video()

    def get_roi(self):
        """返回 (start_x, start_y, width, height, bins)"""
        if self.camera:
            return self.camera.get_roi()
        return (0, 0, 0, 0, 1)

    # ── 视频流 ──

    def start_video(self):
        if not self.camera or self._streaming:
            return
        self._streaming = True
        self.camera.start_video_capture()
        self._stream_thread = threading.Thread(target=self._video_loop, daemon=True)
        self._stream_thread.start()

    def stop_video(self):
        self._streaming = False
        if self._stream_thread:
            self._stream_thread.join(timeout=2)
            self._stream_thread = None
        if self.camera:
            try:
                self.camera.stop_video_capture()
            except Exception:
                pass

    def _video_loop(self):
        while self._streaming and self.camera:
            try:
                buf = self.camera.capture_video_frame()
                if buf is not None:
                    self._last_frame = buf  # 缓存最新帧
                    if self.on_frame:
                        self.on_frame(buf)
            except asi.ZWO_IOError:
                pass
            except Exception as e:
                if self.on_status:
                    self.on_status(f"视频流错误: {e}")
                break

    def capture_save(self, path: str):
        """保存当前帧原样到文件"""
        import cv2

        if self._last_frame is not None:
            frame = self._last_frame.copy()
            cv2.imwrite(path, frame)  # BGR直接存
        elif self.camera and not self._streaming:
            self.camera.capture(filename=path)
        else:
            raise RuntimeError("无可用帧")

    def capture_save_gray(self, path: str):
        """保存真正的RAW16图：停流→切RAW16→snap→切回原格式→恢复流"""
        if not self.camera:
            raise RuntimeError("相机未打开")

        was_streaming = self._streaming
        if was_streaming:
            self.stop_video()

        try:
            # 切到 RAW16 拍一张
            self.camera.set_image_type(asi.ASI_IMG_RAW16)
            self.camera.capture(filename=path)
        finally:
            # 切回原格式
            orig = getattr(self, "_current_img_type", DEFAULT_IMG_TYPE)
            self.camera.set_image_type(IMG_TYPE_MAP.get(orig, asi.ASI_IMG_RGB24))
            if was_streaming:
                self.start_video()

    def snap_raw16(self) -> np.ndarray:
        """停流→切RAW16→snap一帧返回numpy数组→切回原格式→恢复流"""
        if not self.camera:
            raise RuntimeError("相机未打开")

        was_streaming = self._streaming
        if was_streaming:
            self.stop_video()

        try:
            self.camera.set_image_type(asi.ASI_IMG_RAW16)
            raw = self.camera.capture()  # 返回 numpy array (H, W) uint16
            return raw
        finally:
            orig = getattr(self, "_current_img_type", DEFAULT_IMG_TYPE)
            self.camera.set_image_type(IMG_TYPE_MAP.get(orig, asi.ASI_IMG_RGB24))
            if was_streaming:
                self.start_video()

    def capture_save_rgb(self, path: str):
        """保存RGB彩色图（zwoasi返回BGR，cv2.imwrite需要BGR，直接存）"""
        import cv2

        if self._last_frame is None:
            raise RuntimeError("无可用帧")
        frame = self._last_frame.copy()
        if frame.ndim == 3 and frame.shape[2] == 3:
            cv2.imwrite(path, frame)  # 已经是BGR，直接存
        elif frame.ndim == 2:
            bgr = cv2.cvtColor(
                frame.astype(np.uint8) if frame.dtype != np.uint8 else frame,
                cv2.COLOR_GRAY2BGR,
            )
            cv2.imwrite(path, bgr)
        else:
            raise RuntimeError("未知帧格式")


# ═══════════════════════════════════════════════════════
#  主界面
# ═══════════════════════════════════════════════════════


class App(tk.Tk):

    def __init__(self):
        super().__init__()
        self.title("LED + Camera Control")
        self.geometry("1280x720")

        self.led = LedState()
        self.serial_mgr = SerialManager(on_frame=self._on_serial_frame)
        self.cam_mgr = CameraManager()
        self.cam_mgr.on_frame = self._on_camera_frame
        self._photo_image = None  # 保持引用防止 GC

        # ── Tk 变量 ──
        self._port_var = tk.StringVar()
        self._baud_var = tk.StringVar(value="460800")
        self._databits_var = tk.StringVar(value="8")
        self._stopbits_var = tk.StringVar(value="1")
        self._parity_var = tk.StringVar(value="None")
        self._inc_var = tk.IntVar(value=1)
        self._duty_var = tk.IntVar(value=100)
        self._sel_var = tk.IntVar(value=1)
        self._led_vars: list[tk.IntVar] = []
        self._led_spins: list[ttk.Spinbox] = []

        # 串口接收事件（用于 AutoNext 同步）
        self._serial_recv_event = threading.Event()

        # 相机变量
        self._cam_list_var = tk.StringVar()
        self._exp_var = tk.IntVar(value=DEFAULT_EXPOSURE_US)
        self._gain_var = tk.IntVar(value=DEFAULT_GAIN)
        self._imgtype_var = tk.StringVar(value=DEFAULT_IMG_TYPE)
        self._bin_var = tk.IntVar(value=1)
        self._wb_r_var = tk.IntVar(value=DEFAULT_WB_R)
        self._wb_b_var = tk.IntVar(value=DEFAULT_WB_B)
        self._roi_x_var = tk.IntVar(value=DEFAULT_ROI_X)
        self._roi_y_var = tk.IntVar(value=DEFAULT_ROI_Y)
        self._roi_w_var = tk.IntVar(value=DEFAULT_ROI_W)
        self._roi_h_var = tk.IntVar(value=DEFAULT_ROI_H)
        self._fps_var = tk.StringVar(value="FPS: --")
        self._cam_status_var = tk.StringVar(value="未连接")

        # 保存相关
        self._save_index = tk.IntVar(value=1)
        self._save_dir = DEFAULT_SAVE_DIR
        os.makedirs(self._save_dir, exist_ok=True)

        # 布局: 左侧控制面板 | 右侧视频
        left = ttk.Frame(self, width=480)
        left.pack(side="left", fill="y", padx=4, pady=4)
        left.pack_propagate(False)

        right = ttk.Frame(self)
        right.pack(side="left", fill="both", expand=True, padx=4, pady=4)

        self._build_serial_panel(left)
        self._build_led_panel(left)
        self._build_camera_panel(left)
        self._build_video_panel(right)

        self._refresh_ports()
        self._auto_open_serial()
        self._auto_open_camera()
        self.protocol("WM_DELETE_WINDOW", self._on_close)

        # FPS 计算
        self._frame_count = 0
        self._fps_time = time.time()
        self._update_fps()

    # ─────────────────────────────────────
    #  串口面板
    # ─────────────────────────────────────

    def _build_serial_panel(self, parent):
        fr = ttk.LabelFrame(parent, text="串口设置", padding=4)
        fr.pack(fill="x", pady=(0, 4))

        top = ttk.Frame(fr)
        top.pack(fill="x", pady=2)

        ttk.Label(top, text="端口:").pack(side="left")
        self._cb_port = ttk.Combobox(
            top, textvariable=self._port_var, width=8, postcommand=self._refresh_ports
        )
        self._cb_port.pack(side="left", padx=(0, 6))

        ttk.Label(top, text="波特率:").pack(side="left")
        ttk.Combobox(
            top,
            textvariable=self._baud_var,
            width=7,
            values=["9600", "19200", "38400", "57600", "115200", "460800"],
        ).pack(side="left", padx=(0, 6))

        self._btn_serial = ttk.Button(top, text="打开串口", command=self._toggle_serial)
        self._btn_serial.pack(side="left", padx=4)

        # 接收区 (紧凑)
        r1 = ttk.Frame(fr)
        r1.pack(fill="x", pady=2)
        ttk.Label(r1, text="接收:").pack(side="left")
        self._txt_recv = tk.Text(
            r1, height=2, width=40, state="disabled", font=("Consolas", 8)
        )
        self._txt_recv.pack(side="left", padx=2, fill="x", expand=True)
        ttk.Button(r1, text="清", width=3, command=self._clear_recv).pack(side="left")

    # ─────────────────────────────────────
    #  LED 面板
    # ─────────────────────────────────────

    def _build_led_panel(self, parent):
        fr = ttk.LabelFrame(parent, text="LED PWM (0–100)", padding=4)
        fr.pack(fill="x", pady=(0, 4))

        grid = ttk.Frame(fr)
        grid.pack(fill="x")

        for r in range(2):
            for c in range(8):
                idx = r * 8 + c
                cell = ttk.Frame(grid)
                cell.grid(row=r, column=c, padx=2, pady=2)
                ttk.Label(cell, text=f"{idx+1}", font=("", 7)).pack()
                var = tk.IntVar(value=0)
                spin = ttk.Spinbox(
                    cell,
                    from_=0,
                    to=100,
                    width=3,
                    textvariable=var,
                    increment=1,
                    command=lambda i=idx: self._sync_led(i),
                    font=("", 8),
                )
                spin.pack()
                self._led_vars.append(var)
                self._led_spins.append(spin)

        bar = ttk.Frame(fr)
        bar.pack(fill="x", pady=(4, 0))

        ttk.Label(bar, text="步进:").pack(side="left")
        ttk.Spinbox(
            bar,
            from_=1,
            to=100,
            width=3,
            textvariable=self._inc_var,
            command=self._apply_increment,
        ).pack(side="left", padx=(0, 8))

        ttk.Label(bar, text="占空比:").pack(side="left")
        ttk.Spinbox(bar, from_=0, to=100, width=3, textvariable=self._duty_var).pack(
            side="left", padx=(0, 8)
        )

        for txt, cmd in [
            ("发送", self._send_led),
            ("清零", self._clear_leds),
            ("Next", self._next_led),
        ]:
            ttk.Button(bar, text=txt, width=4, command=cmd).pack(side="left", padx=2)

        self._btn_autonext = ttk.Button(
            bar, text="AutoNext", width=8, command=self._start_auto_next
        )
        self._btn_autonext.pack(side="left", padx=4)

        self._btn_benchsave = ttk.Button(
            bar, text="BenchSave", width=9, command=self._start_bench_save
        )
        self._btn_benchsave.pack(side="left", padx=2)

        # 状态行（单独一行，不被截断）
        self._autonext_status_var = tk.StringVar(value="")
        ttk.Label(
            fr,
            textvariable=self._autonext_status_var,
            foreground="blue",
            font=("Consolas", 8),
        ).pack(fill="x", pady=(2, 0))

    # ─────────────────────────────────────
    #  相机面板
    # ─────────────────────────────────────

    def _build_camera_panel(self, parent):
        fr = ttk.LabelFrame(parent, text="ZWO ASI 相机", padding=4)
        fr.pack(fill="x", pady=(0, 4))

        # 连接行
        r0 = ttk.Frame(fr)
        r0.pack(fill="x", pady=2)
        self._cb_cam = ttk.Combobox(
            r0, textvariable=self._cam_list_var, width=20, state="readonly"
        )
        self._cb_cam.pack(side="left", padx=(0, 4))
        ttk.Button(r0, text="扫描", width=4, command=self._scan_cameras).pack(
            side="left", padx=2
        )
        self._btn_cam_open = ttk.Button(
            r0, text="打开相机", width=7, command=self._toggle_camera
        )
        self._btn_cam_open.pack(side="left", padx=2)
        self._btn_stream = ttk.Button(
            r0, text="开始预览", width=7, command=self._toggle_stream, state="disabled"
        )
        self._btn_stream.pack(side="left", padx=2)

        # 状态
        ttk.Label(fr, textvariable=self._cam_status_var, foreground="gray").pack(
            anchor="w"
        )

        # 参数行1: 曝光 + 增益
        r1 = ttk.Frame(fr)
        r1.pack(fill="x", pady=2)

        self._exp_debounce_id = None
        self._gain_debounce_id = None

        ttk.Label(r1, text="曝光(μs):").pack(side="left")
        exp_spin = ttk.Spinbox(
            r1,
            from_=32,
            to=2000000000,
            width=9,
            textvariable=self._exp_var,
            command=self._on_exp_changed,
        )
        exp_spin.pack(side="left", padx=(0, 4))
        exp_spin.bind("<Return>", lambda _: self._apply_exposure())
        self._exp_var.trace_add("write", lambda *_: self._on_exp_changed())

        self._btn_auto_exp = ttk.Button(
            r1, text="自动曝光", width=7, command=self._start_auto_exposure
        )
        self._btn_auto_exp.pack(side="left", padx=(0, 8))

        ttk.Label(r1, text="增益:").pack(side="left")
        gain_spin = ttk.Spinbox(
            r1,
            from_=0,
            to=600,
            width=4,
            textvariable=self._gain_var,
            command=self._on_gain_changed,
        )
        gain_spin.pack(side="left", padx=(0, 8))
        gain_spin.bind("<Return>", lambda _: self._apply_gain())
        self._gain_var.trace_add("write", lambda *_: self._on_gain_changed())

        ttk.Label(r1, text="格式:").pack(side="left", padx=(8, 0))
        fmt_cb = ttk.Combobox(
            r1,
            textvariable=self._imgtype_var,
            width=6,
            state="readonly",
            values=list(IMG_TYPE_MAP.keys()),
        )
        fmt_cb.pack(side="left", padx=(0, 8))
        fmt_cb.bind("<<ComboboxSelected>>", lambda _: self._apply_cam_params())

        ttk.Label(r1, text="Bin:").pack(side="left")
        self._cb_bin = ttk.Combobox(
            r1, textvariable=self._bin_var, width=3, state="readonly", values=["1"]
        )
        self._cb_bin.pack(side="left", padx=(0, 8))
        self._cb_bin.bind("<<ComboboxSelected>>", lambda _: self._apply_cam_params())

        ttk.Label(r1, text="WB_R:").pack(side="left", padx=(8, 0))
        wb_r_spin = ttk.Spinbox(
            r1,
            from_=1,
            to=99,
            width=3,
            textvariable=self._wb_r_var,
            command=self._apply_wb,
        )
        wb_r_spin.pack(side="left", padx=(0, 4))
        wb_r_spin.bind("<Return>", lambda _: self._apply_wb())

        ttk.Label(r1, text="WB_B:").pack(side="left")
        wb_b_spin = ttk.Spinbox(
            r1,
            from_=1,
            to=99,
            width=3,
            textvariable=self._wb_b_var,
            command=self._apply_wb,
        )
        wb_b_spin.pack(side="left", padx=(0, 4))
        wb_b_spin.bind("<Return>", lambda _: self._apply_wb())

        ttk.Label(r1, textvariable=self._fps_var).pack(side="right")

        # ROI 行
        r3 = ttk.LabelFrame(fr, text="ROI", padding=2)
        r3.pack(fill="x", pady=2)

        self._roi_debounce_id = None  # debounce 定时器

        for label, var in [
            ("X:", self._roi_x_var),
            ("Y:", self._roi_y_var),
            ("W:", self._roi_w_var),
            ("H:", self._roi_h_var),
        ]:
            ttk.Label(r3, text=label).pack(side="left")
            spin = ttk.Spinbox(
                r3,
                from_=0,
                to=99999,
                width=5,
                textvariable=var,
                command=self._on_roi_changed,
            )
            spin.bind("<Return>", lambda _: self._apply_roi())
            spin.pack(side="left", padx=(0, 4))
            # 输入框内容变化时也触发 debounce
            var.trace_add("write", lambda *_: self._on_roi_changed())

        ttk.Button(r3, text="全幅", width=4, command=self._reset_roi).pack(
            side="left", padx=2
        )

        # 保存行
        r4 = ttk.LabelFrame(fr, text="保存", padding=2)
        r4.pack(fill="x", pady=2)

        ttk.Button(r4, text="保存灰度", width=7, command=self._save_gray).pack(
            side="left", padx=2
        )
        ttk.Button(r4, text="保存RGB", width=7, command=self._save_rgb).pack(
            side="left", padx=2
        )

        ttk.Label(r4, text="索引:").pack(side="left", padx=(8, 0))
        ttk.Spinbox(r4, from_=1, to=99999, width=4, textvariable=self._save_index).pack(
            side="left", padx=(0, 4)
        )
        ttk.Button(r4, text="Clear", width=4, command=self._clear_save_index).pack(
            side="left", padx=2
        )
        ttk.Button(r4, text="选目录", width=5, command=self._choose_save_dir).pack(
            side="left", padx=2
        )
        ttk.Button(r4, text="打开目录", width=6, command=self._open_save_dir).pack(
            side="left", padx=2
        )

        # 自动曝光行
        r5 = ttk.LabelFrame(fr, text="自动曝光", padding=2)
        r5.pack(fill="x", pady=2)

        ttk.Label(r5, text="过曝比例%:").pack(side="left")
        self._overexp_pct_var = tk.DoubleVar(value=5.0)
        ttk.Spinbox(
            r5,
            from_=0.1,
            to=50.0,
            width=5,
            increment=0.5,
            textvariable=self._overexp_pct_var,
        ).pack(side="left", padx=(0, 8))

        ttk.Label(r5, text="阈值:").pack(side="left")
        self._overexp_thresh_var = tk.IntVar(value=250)
        ttk.Spinbox(
            r5, from_=200, to=255, width=4, textvariable=self._overexp_thresh_var
        ).pack(side="left", padx=(0, 8))

        self._btn_autoexp = ttk.Button(
            r5, text="自动曝光", width=8, command=self._start_auto_exposure
        )
        self._btn_autoexp.pack(side="left", padx=2)

        self._autoexp_status_var = tk.StringVar(value="")
        ttk.Label(r5, textvariable=self._autoexp_status_var, foreground="blue").pack(
            side="left", padx=4
        )

    # ─────────────────────────────────────
    #  视频面板
    # ─────────────────────────────────────

    def _build_video_panel(self, parent):
        fr = ttk.LabelFrame(parent, text="实时预览", padding=2)
        fr.pack(fill="both", expand=True)

        self._canvas = tk.Canvas(fr, bg="black")
        self._canvas.pack(fill="both", expand=True)

        # 直方图 + 统计
        hist_fr = ttk.Frame(fr)
        hist_fr.pack(fill="x", side="bottom")

        self._hist_canvas = tk.Canvas(hist_fr, bg="black", height=80, width=256)
        self._hist_canvas.pack(side="left", padx=(0, 8), pady=2)

        self._hist_stat_var = tk.StringVar(value="Min: --  Max: --  Mean: --")
        ttk.Label(hist_fr, textvariable=self._hist_stat_var, font=("Consolas", 9)).pack(
            side="left", anchor="n", pady=4
        )

    # ═══════════════════════════════════════════════════
    #  串口逻辑
    # ═══════════════════════════════════════════════════

    def _refresh_ports(self):
        ports = [p.device for p in serial.tools.list_ports.comports()]
        self._cb_port["values"] = ports
        if ports and not self._port_var.get():
            self._port_var.set(ports[-1])

    def _auto_open_serial(self):
        """启动后自动打开串口"""
        if self._port_var.get():
            try:
                cfg = SerialConfig(
                    port=self._port_var.get(),
                    baudrate=int(self._baud_var.get()),
                    bytesize=int(self._databits_var.get()),
                    stopbits=self._stopbits_var.get(),
                    parity=self._parity_var.get(),
                )
                self.serial_mgr.open(cfg)
                self._btn_serial.configure(text="关闭串口")
            except Exception:
                pass  # 自动打开失败不弹窗

    def _auto_open_camera(self):
        """启动后自动扫描并打开第一台相机"""
        try:
            names = self.cam_mgr.scan()
            if names:
                self._cb_cam["values"] = names
                self._cb_cam.current(0)
                self.cam_mgr.open(0)
                self._btn_cam_open.configure(text="关闭相机")
                self._btn_stream.configure(state="normal")
                mw, mh = self.cam_mgr.get_max_size()
                bins = self.cam_mgr.get_supported_bins()
                self._cb_bin["values"] = bins
                self._cb_bin.set(bins[0])
                self._cam_status_var.set(f"{names[0]} — {mw}×{mh}")
                self._apply_roi()
                self._toggle_stream()
        except Exception:
            pass  # 自动打开失败不弹窗

    def _toggle_serial(self):
        if self.serial_mgr.is_open:
            self.serial_mgr.close()
            self._btn_serial.configure(text="打开串口")
        else:
            try:
                cfg = SerialConfig(
                    port=self._port_var.get(),
                    baudrate=int(self._baud_var.get()),
                    bytesize=int(self._databits_var.get()),
                    stopbits=self._stopbits_var.get(),
                    parity=self._parity_var.get(),
                )
                self.serial_mgr.open(cfg)
                self._btn_serial.configure(text="关闭串口")
            except Exception as ex:
                messagebox.showerror("串口打开失败", str(ex))

    def _on_serial_frame(self, frame: bytes):
        hex_str = " ".join(f"{b:02X}" for b in frame)
        self.after(0, self._append_recv, hex_str)
        # 通知等待串口回传的线程
        self._serial_recv_event.set()

    def _append_recv(self, text: str):
        w = self._txt_recv
        w.configure(state="normal")
        w.insert("end", text + "\n")
        w.see("end")
        w.configure(state="disabled")

    def _clear_recv(self):
        w = self._txt_recv
        w.configure(state="normal")
        w.delete("1.0", "end")
        w.configure(state="disabled")

    # ═══════════════════════════════════════════════════
    #  LED 逻辑
    # ═══════════════════════════════════════════════════

    def _sync_led(self, idx: int):
        val = max(0, min(100, self._led_vars[idx].get()))
        self._led_vars[idx].set(val)
        self.led.set_channel(idx, val)

    def _ui_from_state(self):
        for i in range(NUM_LEDS):
            self._led_vars[i].set(self.led.pwm[i])

    def _state_from_ui(self):
        for i in range(NUM_LEDS):
            self.led.set_channel(i, self._led_vars[i].get())

    def _apply_increment(self):
        inc = self._inc_var.get()
        for s in self._led_spins:
            s.configure(increment=inc)

    def _send_led(self):
        self._state_from_ui()
        self.serial_mgr.send(self.led.to_bytes())

    def _clear_leds(self):
        self.led.clear()
        self._ui_from_state()

    def _next_led(self):
        brightness = max(0, min(100, self._duty_var.get()))
        non_zero = [
            (i, self._led_vars[i].get())
            for i in range(NUM_LEDS)
            if self._led_vars[i].get() != 0
        ]

        if len(non_zero) == 1:
            cur, _ = non_zero[0]
            if cur in NEXT_LED_CYCLE:
                pos = NEXT_LED_CYCLE.index(cur)
                nxt = NEXT_LED_CYCLE[(pos + 1) % len(NEXT_LED_CYCLE)]
            else:
                nxt = NEXT_LED_CYCLE[0]
        else:
            nxt = NEXT_LED_CYCLE[0]

        self.led.clear()
        self.led.set_channel(nxt, brightness)
        self.led.selected_index = nxt + 1
        self.led.selected_value = brightness

        self._ui_from_state()
        self.serial_mgr.send(self.led.to_bytes())

    # ═══════════════════════════════════════════════════
    #  相机逻辑
    # ═══════════════════════════════════════════════════

    def _scan_cameras(self):
        names = self.cam_mgr.scan()
        self._cb_cam["values"] = names
        if names:
            self._cb_cam.current(0)
            self._cam_status_var.set(f"找到 {len(names)} 台相机")
        else:
            self._cam_status_var.set(
                "未找到相机" + ("" if ASI_AVAILABLE else " (SDK未加载)")
            )

    def _toggle_camera(self):
        if self.cam_mgr.is_open:
            self.cam_mgr.close()
            self._btn_cam_open.configure(text="打开相机")
            self._btn_stream.configure(state="disabled")
            self._cam_status_var.set("已关闭")
        else:
            try:
                idx = self._cb_cam.current()
                if idx < 0:
                    idx = 0
                self.cam_mgr.open(idx)
                self._btn_cam_open.configure(text="关闭相机")
                self._btn_stream.configure(state="normal")
                # 读取相机信息更新 UI
                mw, mh = self.cam_mgr.get_max_size()
                bins = self.cam_mgr.get_supported_bins()
                self._cb_bin["values"] = bins
                self._cb_bin.set(bins[0])
                self._cam_status_var.set(f"{self._cam_list_var.get()} — {mw}×{mh}")
                # 应用 UI 上的默认 ROI
                self._apply_roi()
                # 自动开始预览
                self._toggle_stream()
            except Exception as ex:
                messagebox.showerror("相机打开失败", str(ex))

    def _toggle_stream(self):
        if self.cam_mgr.is_streaming:
            self.cam_mgr.stop_video()
            self._btn_stream.configure(text="开始预览")
        else:
            self.cam_mgr.start_video()
            self._btn_stream.configure(text="停止预览")

    def _on_camera_frame(self, frame: np.ndarray):
        """后台线程回调 → 尽量在后台做完计算，主线程只贴图"""
        import cv2

        self._frame_count += 1
        try:
            # ── 1. 转为显示用 PIL Image（在后台线程做缩放）──
            cw = self._canvas.winfo_width()
            ch = self._canvas.winfo_height()
            if cw < 10 or ch < 10:
                return

            if frame.ndim == 2:
                if frame.dtype == np.uint16:
                    disp = (frame >> 8).astype(np.uint8)
                else:
                    disp = frame
                # 缩放
                iw, ih = disp.shape[1], disp.shape[0]
                scale = min(cw / iw, ch / ih)
                nw, nh = int(iw * scale), int(ih * scale)
                small = cv2.resize(disp, (nw, nh), interpolation=cv2.INTER_NEAREST)
                img = Image.fromarray(small, mode="L")
                gray_for_hist = disp
            elif frame.ndim == 3 and frame.shape[2] == 3:
                # zwoasi RGB24 模式实际返回 BGR 顺序
                iw, ih = frame.shape[1], frame.shape[0]
                scale = min(cw / iw, ch / ih)
                nw, nh = int(iw * scale), int(ih * scale)
                small = cv2.resize(frame, (nw, nh), interpolation=cv2.INTER_NEAREST)
                # BGR → RGB 给 PIL 显示
                img = Image.fromarray(small[:, :, ::-1], mode="RGB")
                # 灰度直方图用 BGR2GRAY
                gray_for_hist = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
            else:
                return

            # ── 2. 直方图每 N 帧算一次 ──
            hist_data = None
            if self._frame_count % 4 == 0:
                hist = cv2.calcHist([gray_for_hist], [0], None, [256], [0, 256]).ravel()
                hist_norm = hist / (hist.max() + 1e-6)
                v_min = int(gray_for_hist.min())
                v_max = int(gray_for_hist.max())
                v_mean = float(gray_for_hist.mean())
                hist_data = (hist_norm, v_min, v_max, v_mean)

            self.after(0, self._display_frame, img, cw, ch, hist_data)
        except Exception:
            pass

    def _display_frame(self, img: Image.Image, cw: int, ch: int, hist_data):
        """主线程：贴预览图 + 可选更新直方图"""
        # 贴预览图
        self._photo_image = ImageTk.PhotoImage(img)
        self._canvas.delete("all")
        self._canvas.create_image(
            cw // 2, ch // 2, image=self._photo_image, anchor="center"
        )

        # 更新直方图（仅当有数据时）
        if hist_data:
            self._display_histogram(*hist_data)

    def _display_histogram(
        self, hist_norm: np.ndarray, v_min: int, v_max: int, v_mean: float
    ):
        """用 PIL 绘制直方图：白底黑柱"""
        cw = self._hist_canvas.winfo_width()
        ch = self._hist_canvas.winfo_height()
        if cw < 10 or ch < 10:
            return

        heights = (hist_norm * (ch - 2)).astype(np.int32)
        rows = np.arange(ch).reshape(-1, 1)
        mask = rows >= (ch - heights)
        img = np.full((ch, 256, 3), 255, dtype=np.uint8)  # 白底
        img[mask] = (30, 30, 30)  # 黑柱

        pil_img = Image.fromarray(img, mode="RGB").resize((cw, ch), Image.NEAREST)
        self._hist_photo = ImageTk.PhotoImage(pil_img)
        self._hist_canvas.delete("all")
        self._hist_canvas.create_image(0, 0, image=self._hist_photo, anchor="nw")

        self._hist_stat_var.set(f"Min: {v_min}  Max: {v_max}  Mean: {v_mean:.1f}")

    def _on_exp_changed(self):
        """曝光变化 debounce"""
        if self._exp_debounce_id:
            self.after_cancel(self._exp_debounce_id)
        self._exp_debounce_id = self.after(300, self._apply_exposure)

    def _on_gain_changed(self):
        """增益变化 debounce"""
        if self._gain_debounce_id:
            self.after_cancel(self._gain_debounce_id)
        self._gain_debounce_id = self.after(300, self._apply_gain)

    def _apply_exposure(self):
        self._exp_debounce_id = None
        try:
            self.cam_mgr.set_exposure(self._exp_var.get())
        except (tk.TclError, ValueError):
            pass

    def _apply_gain(self):
        self._gain_debounce_id = None
        try:
            self.cam_mgr.set_gain(self._gain_var.get())
        except (tk.TclError, ValueError):
            pass

    def _apply_cam_params(self):
        """应用曝光、增益、格式、Bin"""
        self.cam_mgr.set_exposure(self._exp_var.get())
        self.cam_mgr.set_gain(self._gain_var.get())
        self.cam_mgr.set_image_type(self._imgtype_var.get())
        # Bin + ROI 一起设
        self._apply_roi()

    def _apply_wb(self):
        """应用白平衡 WB_R / WB_B"""
        if self.cam_mgr.is_open and self.cam_mgr.camera:
            try:
                self.cam_mgr.camera.set_control_value(
                    asi.ASI_WB_R, self._wb_r_var.get()
                )
                self.cam_mgr.camera.set_control_value(
                    asi.ASI_WB_B, self._wb_b_var.get()
                )
            except Exception:
                pass

    def _on_roi_changed(self):
        """ROI spinbox 变化时的 debounce：300ms 内无新变化才实际应用"""
        if self._roi_debounce_id:
            self.after_cancel(self._roi_debounce_id)
        self._roi_debounce_id = self.after(300, self._apply_roi)

    def _apply_roi(self):
        self._roi_debounce_id = None
        if not self.cam_mgr.is_open:
            return
        bins = self._bin_var.get()
        try:
            x, y = self._roi_x_var.get(), self._roi_y_var.get()
            w, h = self._roi_w_var.get(), self._roi_h_var.get()
        except (tk.TclError, ValueError):
            return  # 用户正在输入，值暂时无效
        if w < 8 or h < 2:
            return
        try:
            self.cam_mgr.set_roi(x, y, w, h, bins)
            self._cam_status_var.set(f"ROI: ({x},{y}) {w}×{h} Bin{bins}")
        except Exception as ex:
            self._cam_status_var.set(f"ROI错误: {ex}")

    def _reset_roi(self):
        mw, mh = self.cam_mgr.get_max_size()
        bins = self._bin_var.get()
        self._roi_x_var.set(0)
        self._roi_y_var.set(0)
        self._roi_w_var.set(mw // bins)
        self._roi_h_var.set(mh // bins)
        self._apply_roi()

    def _save_gray(self):
        """保存灰度图: Violet_曝光时间_索引号.png，索引自增"""
        exp = self._exp_var.get()
        idx = self._save_index.get()
        filename = f"{SAVE_PREFIX}{exp}_{idx}.png"
        path = os.path.join(self._save_dir, filename)
        try:
            self.cam_mgr.capture_save_gray(path)
            self._cam_status_var.set(f"已保存: {filename}")
            self._save_index.set(idx + 1)
        except Exception as ex:
            self._cam_status_var.set(f"保存失败: {ex}")

    def _save_rgb(self):
        """保存RGB图: Violet_曝光时间_rgb.png，仅LED8亮时建议使用"""
        exp = self._exp_var.get()
        filename = f"{SAVE_PREFIX}{exp}_rgb.png"
        path = os.path.join(self._save_dir, filename)
        try:
            self.cam_mgr.capture_save_rgb(path)
            self._cam_status_var.set(f"已保存: {filename}")
        except Exception as ex:
            self._cam_status_var.set(f"保存失败: {ex}")

    def _clear_save_index(self):
        self._save_index.set(1)

    def _choose_save_dir(self):
        d = filedialog.askdirectory(initialdir=self._save_dir)
        if d:
            self._save_dir = d
            os.makedirs(self._save_dir, exist_ok=True)
            self._cam_status_var.set(f"保存目录: {d}")

    def _open_save_dir(self):
        """用系统文件管理器打开保存目录"""
        import subprocess, platform

        path = os.path.abspath(self._save_dir)
        os.makedirs(path, exist_ok=True)
        if platform.system() == "Windows":
            os.startfile(path)
        elif platform.system() == "Darwin":
            subprocess.Popen(["open", path])
        else:
            subprocess.Popen(["xdg-open", path])

    # ─────────────────────────────────────
    #  自动曝光
    # ─────────────────────────────────────

    def _start_auto_exposure(self):
        """手动点击自动曝光按钮"""
        if not self.cam_mgr.is_open or not self.cam_mgr.is_streaming:
            self._autoexp_status_var.set("需先开启预览")
            return
        self._btn_autoexp.configure(state="disabled")
        self._autoexp_status_var.set("调节中...")
        threading.Thread(target=self._run_auto_exposure_standalone, daemon=True).start()

    def _run_auto_exposure_standalone(self):
        """独立运行自动曝光（手动按钮用）"""
        self._run_auto_exposure()
        self.after(0, lambda: self._btn_autoexp.configure(state="normal"))

    def _run_auto_exposure(self):
        """
        自动曝光（基于真 RAW16）：
        用第95百分位值（即前5%最亮像素的下界）作为亮度指标。
        目标: P95 落在 RAW_TARGET 附近。

        RAW16 范围 0~65535。换算: raw = 8bit_val / 255 * 65535
        """
        RAW_P95_LO = 41120  # 160 @8bit
        RAW_P95_HI = 51400  # 200 @8bit
        RAW_P95_TARGET = 46260  # 180 @8bit
        max_iter = 10
        min_exp = 32
        max_exp = 2000000

        cur_exp = self._exp_var.get()

        for i in range(max_iter):
            try:
                raw = self.cam_mgr.snap_raw16()
            except Exception as ex:
                self.after(0, self._autoexp_status_var.set, f"snap失败: {ex}")
                return

            if raw is None:
                continue

            # 第95百分位：前5%最亮像素的下界
            p95 = int(np.percentile(raw, 95))
            v_max = int(raw.max())
            p95_8b = p95 * 255 / 65535
            max_8b = v_max * 255 / 65535

            status = f"#{i+1} exp={cur_exp} P95={p95}({p95_8b:.0f}@8b) max={v_max}({max_8b:.0f}@8b)"
            self.after(0, self._autoexp_status_var.set, status)

            # 收敛：P95 落在目标范围内
            if RAW_P95_LO <= p95 <= RAW_P95_HI:
                self.after(
                    0,
                    self._autoexp_status_var.set,
                    f"完成! exp={cur_exp} P95={p95}({p95_8b:.0f}@8b)",
                )
                return

            # 一步估算: new_exp = cur_exp * target / p95
            if p95 <= 10:
                new_exp = cur_exp * 8
            else:
                new_exp = int(cur_exp * RAW_P95_TARGET / max(p95, 1))

            new_exp = max(min_exp, min(new_exp, max_exp))

            if new_exp == cur_exp:
                new_exp = cur_exp + (100 if p95 < RAW_P95_TARGET else -100)
                new_exp = max(min_exp, min(new_exp, max_exp))

            cur_exp = new_exp
            self.cam_mgr.set_exposure(cur_exp)
            self.after(0, self._exp_var.set, cur_exp)

        self.after(
            0,
            self._autoexp_status_var.set,
            f"结束 exp={cur_exp} P95={p95}({p95_8b:.0f}@8b)",
        )

    # ─────────────────────────────────────
    #  AutoNext：自动循环 LED → 等串口回传 → 自动曝光 → 保存
    # ─────────────────────────────────────

    def _start_auto_next(self):
        """启动 AutoNext 流程"""
        if not self.cam_mgr.is_open or not self.cam_mgr.is_streaming:
            self._autonext_status_var.set("需先开启预览")
            return
        if not self.serial_mgr.is_open:
            self._autonext_status_var.set("需先打开串口")
            return
        # 禁用相关按钮
        self._btn_autonext.configure(state="disabled")
        self._btn_autoexp.configure(state="disabled")
        self._autonext_status_var.set("开始...")
        threading.Thread(target=self._auto_next_loop, daemon=True).start()

    def _auto_next_loop(self):
        """
        后台线程：依次遍历 NEXT_LED_CYCLE 中的每个 LED：
          1. 切换 LED 并发送串口
          2. 等待串口接收到 MCU 回传（确认收到）
          3. 运行自动曝光
          4. 保存灰度图
        """
        brightness = max(0, min(100, self._duty_var.get()))

        for step, led_idx in enumerate(NEXT_LED_CYCLE):
            led_name = f"LED{led_idx + 1}"
            self.after(
                0,
                self._autonext_status_var.set,
                f"[{step+1}/{len(NEXT_LED_CYCLE)}] {led_name} 切换中...",
            )

            # ── 1. 切换 LED ──
            self.led.clear()
            self.led.set_channel(led_idx, brightness)
            self.led.selected_index = led_idx + 1
            self.led.selected_value = brightness
            self.after(0, self._ui_from_state)

            # 清除旧的接收事件，发送LED值
            self._serial_recv_event.clear()
            self.serial_mgr.send(self.led.to_bytes())

            # ── 2. 等待串口回传 ──
            self.after(
                0,
                self._autonext_status_var.set,
                f"[{step+1}/{len(NEXT_LED_CYCLE)}] {led_name} 等待MCU回传...",
            )
            if not self._serial_recv_event.wait(timeout=5.0):
                self.after(0, self._autonext_status_var.set, f"{led_name} 串口超时!")
                break

            # 等一小段让画面稳定
            time.sleep(0.3)

            # ── 3. 自动曝光 ──
            self.after(
                0,
                self._autonext_status_var.set,
                f"[{step+1}/{len(NEXT_LED_CYCLE)}] {led_name} 自动曝光...",
            )
            self._run_auto_exposure()

            # ── 4. 保存灰度图 ──
            self.after(
                0,
                self._autonext_status_var.set,
                f"[{step+1}/{len(NEXT_LED_CYCLE)}] {led_name} 保存中...",
            )
            self.after(0, self._save_gray)

            time.sleep(0.2)  # 等保存完成

        self.after(0, self._autonext_status_var.set, "AutoNext 完成!")
        self.after(0, lambda: self._btn_autonext.configure(state="normal"))
        self.after(0, lambda: self._btn_benchsave.configure(state="normal"))
        self.after(0, lambda: self._btn_autoexp.configure(state="normal"))

    # ─────────────────────────────────────
    #  BenchSave：AutoNext + 每步自动保存
    # ─────────────────────────────────────

    def _start_bench_save(self):
        """启动 BenchSave 流程"""
        if not self.cam_mgr.is_open or not self.cam_mgr.is_streaming:
            self._autonext_status_var.set("需先开启预览")
            return
        if not self.serial_mgr.is_open:
            self._autonext_status_var.set("需先打开串口")
            return
        self._btn_autonext.configure(state="disabled")
        self._btn_benchsave.configure(state="disabled")
        self._btn_autoexp.configure(state="disabled")
        self._autonext_status_var.set("BenchSave 开始...")
        threading.Thread(target=self._bench_save_loop, daemon=True).start()

    def _bench_save_loop(self):
        """
        后台线程：依次遍历 NEXT_LED_CYCLE，每个 LED：
          1. 切换 LED → 等串口回传
          2. 自动曝光
          3. 保存灰度图 (所有LED)
          4. 如果是 LED8，额外保存 RGB 图
        图片保存到以时间戳命名的子文件夹中。
        """
        from datetime import datetime

        t_start = time.time()
        brightness = max(0, min(100, self._duty_var.get()))

        # 创建子文件夹: ./data/bench_20250305_143021/
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        bench_dir = os.path.join(self._save_dir, f"bench_{timestamp}")
        os.makedirs(bench_dir, exist_ok=True)

        # 索引从1开始
        save_idx = 1

        for step, led_idx in enumerate(NEXT_LED_CYCLE):
            t_step = time.time()
            led_name = f"LED{led_idx + 1}"
            self.after(
                0,
                self._autonext_status_var.set,
                f"BS [{step+1}/{len(NEXT_LED_CYCLE)}] {led_name} 切换...",
            )

            # ── 1. 切换 LED ──
            self.led.clear()
            self.led.set_channel(led_idx, brightness)
            self.led.selected_index = led_idx + 1
            self.led.selected_value = brightness
            self.after(0, self._ui_from_state)

            self._serial_recv_event.clear()
            self.serial_mgr.send(self.led.to_bytes())

            # ── 2. 等待串口回传 ──
            self.after(
                0,
                self._autonext_status_var.set,
                f"BS [{step+1}/{len(NEXT_LED_CYCLE)}] {led_name} 等MCU...",
            )
            if not self._serial_recv_event.wait(timeout=5.0):
                self.after(0, self._autonext_status_var.set, f"{led_name} 串口超时!")
                break

            time.sleep(0.3)

            # ── 3. 自动曝光 ──
            self.after(
                0,
                self._autonext_status_var.set,
                f"BS [{step+1}/{len(NEXT_LED_CYCLE)}] {led_name} 自动曝光...",
            )
            self._run_auto_exposure()

            # ── 4. 保存灰度图 ──
            exp = self._exp_var.get()
            gray_name = f"{SAVE_PREFIX}{exp}_{save_idx}.png"
            gray_path = os.path.join(bench_dir, gray_name)
            try:
                self.cam_mgr.capture_save_gray(gray_path)
                self.after(0, self._cam_status_var.set, f"已保存: {gray_name}")
                save_idx += 1
            except Exception as ex:
                self.after(0, self._cam_status_var.set, f"灰度保存失败: {ex}")

            # ── 5. LED8 额外保存 RGB ──
            if led_idx == LED8_INDEX:
                rgb_name = f"{SAVE_PREFIX}{exp}_rgb.png"
                rgb_path = os.path.join(bench_dir, rgb_name)
                try:
                    self.cam_mgr.capture_save_rgb(rgb_path)
                    self.after(0, self._cam_status_var.set, f"已保存: {rgb_name}")
                except Exception as ex:
                    self.after(0, self._cam_status_var.set, f"RGB保存失败: {ex}")

            time.sleep(0.1)
            step_elapsed = time.time() - t_step
            self.after(
                0,
                self._autonext_status_var.set,
                f"BS [{step+1}/{len(NEXT_LED_CYCLE)}] {led_name} 完成 {step_elapsed:.1f}s",
            )

        total_elapsed = time.time() - t_start
        # 重置索引为1
        self.after(0, self._save_index.set, 1)
        self.after(
            0,
            self._autonext_status_var.set,
            f"BenchSave 完成! 总耗时 {total_elapsed:.1f}s → {os.path.basename(bench_dir)}",
        )
        self.after(0, lambda: self._btn_autonext.configure(state="normal"))
        self.after(0, lambda: self._btn_benchsave.configure(state="normal"))
        self.after(0, lambda: self._btn_autoexp.configure(state="normal"))

    def _update_fps(self):
        now = time.time()
        dt = now - self._fps_time
        if dt >= 1.0:
            fps = self._frame_count / dt
            self._fps_var.set(f"FPS: {fps:.1f}")
            self._frame_count = 0
            self._fps_time = now
        self.after(1000, self._update_fps)

    # ─────────────────────────────────────
    #  关闭
    # ─────────────────────────────────────

    def _on_close(self):
        self.cam_mgr.close()
        self.serial_mgr.close()
        self.destroy()


if __name__ == "__main__":
    App().mainloop()
