using System;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;
using System.Runtime.InteropServices;
using System.Threading;
using NetOceanDirect;
using OpenCvSharp;
using OpenCvSharp.Extensions;
using ZWOptical.ASISDK;

namespace ASICamera_demo
{
    #region Other Class
    #region SemaphoreHolder
    public static class SemaphoreHolder
    {
        // Meter类相关
        public static bool is_meter_changed = false;
        public static bool search_send_led_ok = false;

        // 初始化信号量，初始计数为 3，最大计数也为 3
        public static Semaphore set = new Semaphore(3, 3);
        public static Stopwatch stopwatch = new Stopwatch();
        public static Stopwatch sw1 = new Stopwatch();
        public static Stopwatch sw_serial = new Stopwatch();

        // 定义读写锁
        public static ReaderWriterLockSlim rwLock = new ReaderWriterLockSlim();

        // 标志位
        public static bool is_std = false;
        public static bool is_changed = false;
        public static bool is_mono = false;

        public static bool is_search = false;
        public static bool is_mono_exp = false;
        public static bool is_break = false;
        public static bool is_manual = false;
        public static bool is_ui_init = false;

        // LED调制完成后串口接收确认信号
        public static bool is_received_auto = false;

        // 是否开启auto连续拍照
        public static bool is_save_auto = false;
        public static bool is_hist_updated = false;
        public static bool is_changed_ok = false;
        public static bool is_updated_auto = false;
        public static bool is_confirmed_auto = false;
        public static bool is_search_hist = false;

        // 最佳曝光计数
        public static int best_exp_count = 0;
        public static int get_video_count = 7;

        // 手动捕获计数
        public static int manual_count = 0;

        // 采样计数
        public static int sample_count = 100;

        // 过曝计数
        public static int over_exp_count = 0;
        public static int count = 0;

        public static bool is_save_meter { get; internal set; }
    }
    #endregion
    public class LedArray
    {
        // 存储led最小/最大PWM时恰好曝光所需的曝光时间;min, max, mean, std灰度值
        private int[,] m_pwm_exp = new int[16, 5];

        private int current_min_led;
        private int current_max_led;
        private int current_min_exp;
        private int current_max_exp;

        private int best_exp;
        private byte[] index = new byte[16];
        private byte[] value = new byte[16];
        private byte selected_index = 2;
        private byte selected_value = 0;
        private byte stride = 1;

        public LedArray()
        {
            for (int i = 0; i < 16; i++)
            {
                Index[i] = (byte)(i + 1);
                Value[i] = 0;
            }
        }

        public byte[] Index
        {
            get => index;
            set => index = value;
        }
        public byte[] Value
        {
            get => value;
            set => this.value = value;
        }
        public byte Selected_index
        {
            get => selected_index;
            set => selected_index = value;
        }
        public byte Selected_value
        {
            get => selected_value;
            set => selected_value = value;
        }
        public byte Stride
        {
            get => stride;
            set => stride = value;
        }
        public int[,] Pwm_exp
        {
            get => m_pwm_exp;
            set => m_pwm_exp = value;
        }
        public int Best_exp
        {
            get => best_exp;
            set => best_exp = value;
        }

        public int Current_max_led
        {
            get => current_max_led;
            set => current_max_led = value;
        }

        public int Current_max_exp
        {
            get => current_max_exp;
            set => current_max_exp = value;
        }
        public int Current_min_led
        {
            get => current_min_led;
            set => current_min_led = value;
        }
        public int Current_min_exp
        {
            get => current_min_exp;
            set => current_min_exp = value;
        }
    }
    #endregion
    #region Class Spectrometer
    class Meter
    {
        public OceanDirect ocean;
        Thread meterThread;
        private int errorCode = 0;
        private Devices[] devices;
        private int deviceID;
        private uint expTime;
        private uint curExpTime;
        private int num = 380;
        public int count = 0;

        // 委托事件
        public delegate void RefreshDataCallBack(int flag);
        private RefreshDataCallBack RefreshData;

        public void SetRefreshDataCallBack(RefreshDataCallBack callBack)
        {
            RefreshData = callBack;
        }

        // 记录400-700nm对应的381个索引
        private int[] inxR;

        // 记录400-700nm对应的光谱
        private double[] spectrum = new double[380];
        public OceanDirect Ocean
        {
            get => ocean;
            set => ocean = value;
        }
        public int DeviceID
        {
            get => deviceID;
            set => deviceID = value;
        }
        public Devices[] Devices
        {
            get => devices;
            set => devices = value;
        }
        public int ErrorCode
        {
            get => errorCode;
            set => errorCode = value;
        }
        public uint ExpTime
        {
            get => expTime;
            set => expTime = value;
        }
        public double[] Spectrum
        {
            get => spectrum;
            set => spectrum = value;
        }

        public Meter()
        {
            meterThread = new Thread(new ThreadStart(run));
            meterThread.Name = "Meter Thread";
        }

        public void startMeterThread()
        {
            if (errorCode == 0)
            {
                double lo = 400;
                double hi = 700;
                double[] waves = new double[num];
                Console.WriteLine("Wavelengths from approx {0} nm to {1} nm.", lo, hi);
                inxR = ocean.getIndicesAtWavelengthRange(
                    DeviceID,
                    ref errorCode,
                    ref waves,
                    lo,
                    hi
                );
                for (int i = 0; i < inxR.Length; i++)
                {
                    Console.Write("Range Index at: {0} == ", inxR[i]);
                    Console.WriteLine("Range Value is: {0}\n", waves[i]);
                }
                meterThread.Start();
            }
            else { }
        }

        public void startTestThread()
        { // Test专用
            // 填充数组
            Random random = new Random();
            // 定义数组长度和范围
            int length = 380;
            double min = 100000;
            double max = 200000;
            for (int i = 0; i < 380; i++)
            {
                // 生成随机数
                Spectrum[i] = random.NextDouble() * (max - min) + min;
            }
            var thread = new Thread(() =>
            {
                while (true)
                {
                    Thread.Sleep(1000);
                }
            });
            thread.Start();
        }

        public void setExpTime(uint time)
        {
            expTime = time;
            SemaphoreHolder.is_meter_changed = true;
        }

        public void run()
        {
            while (true)
            {
                // 更新光谱值
                if (SemaphoreHolder.is_meter_changed)
                {
                    SemaphoreHolder.is_meter_changed = false;
                    Ocean.setIntegrationTimeMicros(DeviceID, ref errorCode, expTime);
                    if (errorCode == 0)
                    {
                        // get曝光时间
                        var itime = Ocean.getIntegrationTimeMicros(DeviceID, ref errorCode);
                        if (itime == expTime)
                        {
                            Console.WriteLine("Set Integration Time Success.");
                        }
                        else
                        {
                            Console.WriteLine("Set Integration Time Failed.");
                        }
                    }
                    else
                    {
                        Console.WriteLine("Set Integration Time Failed.");
                    }
                }

                // 更新光谱数据
                double[] spectrum_raw = ocean.getSpectrum(DeviceID, ref errorCode);
                // 复制指定范围内的元素到新数组
                Array.Copy(spectrum_raw, inxR[0], Spectrum, 0, inxR.Length);
                RefreshData(0);
                // 手动保存图片
                if (SemaphoreHolder.is_save_meter)
                {
                    RefreshData(1);
                    SemaphoreHolder.is_save_meter = false;
                }
                curExpTime = expTime;
                Thread.Sleep(1000);
            }
        }
    }
    #endregion
    class Camera
    {
        #region Class Camera Struct
        public enum CaptureMode
        {
            Video = 0,
            Snap = 1,
        };

        // 最佳曝光值
        private int best_exp;

        //保存图片名
        private static string datetime = Convert.ToString(
            DateTime.Now.ToString("yyyy-MM-dd-HH_mm")
        );
        private static string defaultPath = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.MyDocuments),
            "cmos_led"
        );
        private string selectedFolderPath = defaultPath + '\\' + Datetime;
        private string file_name;

        private string m_cameraName = "";

        // 标准格式：曝光、RAW GAIN
        private ASICameraDll2.ASI_IMG_TYPE m_imgType = ASICameraDll2.ASI_IMG_TYPE.ASI_IMG_RAW8;
        private ASICameraDll2.ASI_IMG_TYPE cur_type = ASICameraDll2.ASI_IMG_TYPE.ASI_IMG_RAW8;
        private int m_expMs = 0;
        private int cur_exp_ms = 0;
        private int m_gain = 0;
        private int cur_gain = 0;

        // private ASICameraDll2.ASI_SN m_SN;
        private CaptureMode m_CaptureMode = CaptureMode.Video;
        private int m_iCameraID;
        private int m_iMaxWidth;
        private int m_iMaxHeight;
        private int m_iCurWidth;
        private int m_iCurHeight;
        private int m_iSize;
        private int m_iBin;
        private int[] m_supBins = new int[16];
        private ASICameraDll2.ASI_IMG_TYPE[] m_supVideoFormats = new ASICameraDll2.ASI_IMG_TYPE[8];
        private int m_iCurrentGainValue;

        private int m_iCurrentWBR;
        private int m_iCurrentWBB;
        private int m_iCurrentBandWidth;

        private int m_iTemperature;
        private int m_iCurrentOffset;
        private int m_iMaxGainValue;
        private int m_iMaxWBRValue;
        private int m_iMaxWBBValue;
        private int m_iMaxOffset;
        private bool m_bIsOpen = false;
        private bool m_bIsColor = false;
        private bool m_bIsCooler = false;
        private bool m_bIsUSB3 = false;
        private bool m_bIsUSB3Host = false;

        private bool m_bGainAutoChecked = false;
        private bool m_bExposureAutoChecked = false;
        private bool m_bWhiteBalanceAutoChecked = false;
        private bool m_bBandWidthAutoChecked = false;

        /*hist*/
        private double min_hist;
        private double max_hist;
        private double mean_hist;
        private double std_hist;
        public Mat save_mat;

        private System.Timers.Timer m_timer = new System.Timers.Timer(500); // 实例化Timer类，设置间隔时间为1000毫秒

        // 定义2个线程
        Thread captureThread;

        public int getCurrentExpMs()
        {
            return m_expMs;
        }

        public int getCurrentGain()
        {
            return m_iCurrentGainValue;
        }

        public int getCurrentWBR()
        {
            return m_iCurrentWBR;
        }

        public int getCurrentWBB()
        {
            return m_iCurrentWBB;
        }

        public int getCurrentBandWidth()
        {
            return m_iCurrentBandWidth;
        }

        public int getCurrentOffset()
        {
            return m_iCurrentOffset;
        }

        public int getMaxOffset()
        {
            return m_iMaxOffset;
        }

        public int getMaxGain()
        {
            return m_iMaxGainValue;
        }

        public int getMaxWBR()
        {
            return m_iMaxWBRValue;
        }

        public int getMaxWBB()
        {
            return m_iMaxWBBValue;
        }

        public int getMaxWidth()
        {
            return m_iMaxWidth;
        }

        public int getMaxHeight()
        {
            return m_iMaxHeight;
        }

        public bool getIsColor()
        {
            return m_bIsColor;
        }

        public bool getIsCooler()
        {
            return m_bIsCooler;
        }

        public bool getIsUSB3()
        {
            return m_bIsUSB3;
        }

        public bool getIsUSB3Host()
        {
            return m_bIsUSB3Host;
        }

        public int[] getBinArr()
        {
            return m_supBins;
        }

        public ASICameraDll2.ASI_IMG_TYPE[] getImgTypeArr()
        {
            return m_supVideoFormats;
        }
        #endregion
        #region LockBitmap
        public class LockBitmap
        {
            private readonly Bitmap _source = null;
            IntPtr _iptr = IntPtr.Zero;
            BitmapData _bitmapData = null;

            public byte[] Pixels { get; set; }
            public int Depth { get; private set; }
            public int Width { get; private set; }
            public int Height { get; private set; }

            public LockBitmap(Bitmap source)
            {
                this._source = source;
            }

            public Bitmap getBitmap()
            {
                return _source;
            }

            /// <summary>
            /// 锁定位图数据
            /// </summary>
            public void LockBits()
            {
                try
                {
                    // 获取位图的宽和高
                    Width = _source.Width;
                    Height = _source.Height;

                    // 获取锁定像素点的总数
                    int pixelCount = Width * Height;

                    // 创建锁定的范围
                    Rectangle rect = new Rectangle(0, 0, Width, Height);

                    // 获取像素格式大小
                    Depth = Image.GetPixelFormatSize(_source.PixelFormat);

                    // 检查像素格式
                    if (Depth != 8 && Depth != 24 && Depth != 32)
                    {
                        throw new ArgumentException("仅支持8,24和32像素位数的图像");
                    }

                    // 锁定位图并返回位图数据
                    _bitmapData = _source.LockBits(
                        rect,
                        ImageLockMode.ReadWrite,
                        _source.PixelFormat
                    );

                    // 创建字节数组以复制像素值
                    int step = Depth / 8;
                    Pixels = new byte[pixelCount * step];
                    _iptr = _bitmapData.Scan0;

                    // 将数据从指针复制到数组
                    Marshal.Copy(_iptr, Pixels, 0, Pixels.Length);
                }
                catch (Exception ex)
                {
                    throw ex;
                }
            }

            /// <summary>
            /// 解锁位图数据
            /// </summary>
            public void UnlockBits()
            {
                try
                {
                    // 将数据从字节数组复制到指针
                    Marshal.Copy(Pixels, 0, _iptr, Pixels.Length);

                    // 解锁位图数据
                    _source.UnlockBits(_bitmapData);
                }
                catch (Exception ex)
                {
                    throw ex;
                }
            }

            /// <summary>
            /// 获取像素点的颜色
            /// </summary>
            /// <param name="x"></param>
            /// <param name="y"></param>
            /// <returns></returns>
            public Color GetPixel(int x, int y)
            {
                Color clr = Color.Empty;

                // 获取颜色组成数量
                int cCount = Depth / 8;

                // 获取指定像素的起始索引
                int i = ((y * Width) + x) * cCount;

                if (i > Pixels.Length - cCount)
                    throw new IndexOutOfRangeException();

                if (Depth == 32) // 获得32 bpp红色，绿色，蓝色和Alpha
                {
                    byte b = Pixels[i];
                    byte g = Pixels[i + 1];
                    byte r = Pixels[i + 2];
                    byte a = Pixels[i + 3]; // a
                    clr = Color.FromArgb(a, r, g, b);
                }

                if (Depth == 24) // 获得24 bpp红色，绿色和蓝色
                {
                    byte b = Pixels[i];
                    byte g = Pixels[i + 1];
                    byte r = Pixels[i + 2];
                    clr = Color.FromArgb(r, g, b);
                }

                if (Depth == 8) // 获得8 bpp
                {
                    byte c = Pixels[i];
                    clr = Color.FromArgb(c, c, c);
                }
                return clr;
            }

            /// <summary>
            /// 设置像素点颜色
            /// </summary>
            /// <param name="x"></param>
            /// <param name="y"></param>
            /// <param name="color"></param>
            public void SetPixel(int x, int y, Color color)
            {
                // 获取颜色组成数量
                int cCount = Depth / 8;

                // 获取指定像素的起始索引
                int i = ((y * Width) + x) * cCount;

                if (Depth == 32)
                {
                    Pixels[i] = color.B;
                    Pixels[i + 1] = color.G;
                    Pixels[i + 2] = color.R;
                    Pixels[i + 3] = color.A;
                }
                if (Depth == 24)
                {
                    Pixels[i] = color.B;
                    Pixels[i + 1] = color.G;
                    Pixels[i + 2] = color.R;
                }
                if (Depth == 8)
                {
                    Pixels[i] = color.B;
                }
            }
        }
        #endregion
        // Constructor
        public Camera()
        {
            captureThread = new Thread(new ThreadStart(run));
            captureThread.Name = "Video";
            m_timer.Elapsed += new System.Timers.ElapsedEventHandler(timeout); // 到达时间的时候执行事件
            m_timer.AutoReset = true; // 设置是执行一次（false）还是一直执行(true)
            m_timer.Start();
        }

        #region Class Camera Default Function
        private void timeout(object source, System.Timers.ElapsedEventArgs e)
        {
            if (!m_bIsOpen)
                return;

            int iVal = 0;

            iVal = ASICameraDll2.ASIGetControlValue(
                ICameraID,
                ASICameraDll2.ASI_CONTROL_TYPE.ASI_TEMPERATURE
            );
            PopupMessageBox("Get Temperature", iVal);

            if (m_bGainAutoChecked)
            {
                if (getControlValue(ASICameraDll2.ASI_CONTROL_TYPE.ASI_GAIN, out iVal))
                {
                    PopupMessageBox("Gain Auto", iVal);
                }
            }
            if (m_bExposureAutoChecked)
            {
                if (getControlValue(ASICameraDll2.ASI_CONTROL_TYPE.ASI_EXPOSURE, out iVal))
                {
                    PopupMessageBox("Exposure Auto", iVal);
                }
            }

            if (m_bWhiteBalanceAutoChecked)
            {
                if (getControlValue(ASICameraDll2.ASI_CONTROL_TYPE.ASI_WB_B, out iVal))
                {
                    PopupMessageBox("White Balance Blue Auto", iVal);
                }
                if (getControlValue(ASICameraDll2.ASI_CONTROL_TYPE.ASI_WB_R, out iVal))
                {
                    PopupMessageBox("White Balance Red Auto", iVal);
                }
            }
            if (m_bBandWidthAutoChecked)
            {
                if (getControlValue(ASICameraDll2.ASI_CONTROL_TYPE.ASI_BANDWIDTHOVERLOAD, out iVal))
                {
                    PopupMessageBox("BandWidth Auto", iVal);
                }
            }
        }

        // camera Init
        private bool cameraInit()
        {
            ASICameraDll2.ASI_ERROR_CODE err;
            int cameraNum = ASICameraDll2.ASIGetNumOfConnectedCameras();
            if (cameraNum == 0)
            {
                PopupMessageBox("No Camera Connection");
                return false;
            }

            ASICameraDll2.ASI_CAMERA_INFO CamInfoTemp;
            ASICameraDll2.ASIGetCameraProperty(out CamInfoTemp, 0);

            for (int i = 0; i < 16; i++)
            {
                m_supBins[i] = 0;
            }
            int index = 0;
            while (CamInfoTemp.SupportedBins[index] != 0)
            {
                m_supBins[index] = CamInfoTemp.SupportedBins[index];
                index++;
            }

            for (int i = 0; i < 8; i++)
            {
                m_supVideoFormats[i] = ASICameraDll2.ASI_IMG_TYPE.ASI_IMG_END;
            }
            index = 0;
            while (
                CamInfoTemp.SupportedVideoFormat[index] != ASICameraDll2.ASI_IMG_TYPE.ASI_IMG_END
            )
            {
                m_supVideoFormats[index] = CamInfoTemp.SupportedVideoFormat[index];
                index++;
            }

            err = ASICameraDll2.ASIOpenCamera(ICameraID);
            if (err != ASICameraDll2.ASI_ERROR_CODE.ASI_SUCCESS)
            {
                return false;
            }

            err = ASICameraDll2.ASIInitCamera(ICameraID);
            if (err != ASICameraDll2.ASI_ERROR_CODE.ASI_SUCCESS)
            {
                return false;
            }

            int iCtrlNum;
            ASICameraDll2.ASI_CONTROL_CAPS CtrlCap;
            ASICameraDll2.ASIGetNumOfControls(ICameraID, out iCtrlNum);

            for (int i = 0; i < iCtrlNum; i++)
            {
                ASICameraDll2.ASIGetControlCaps(ICameraID, i, out CtrlCap);
                if (CtrlCap.ControlType == ASICameraDll2.ASI_CONTROL_TYPE.ASI_GAIN)
                {
                    m_iMaxGainValue = CtrlCap.MaxValue;
                }
                else if (CtrlCap.ControlType == ASICameraDll2.ASI_CONTROL_TYPE.ASI_WB_R)
                {
                    m_iMaxWBRValue = CtrlCap.MaxValue;
                }
                else if (CtrlCap.ControlType == ASICameraDll2.ASI_CONTROL_TYPE.ASI_WB_B)
                {
                    m_iMaxWBBValue = CtrlCap.MaxValue;
                }
            }

            m_iCurrentGainValue = ASICameraDll2.ASIGetControlValue(
                ICameraID,
                ASICameraDll2.ASI_CONTROL_TYPE.ASI_GAIN
            );
            m_expMs = ASICameraDll2.ASIGetControlValue(
                ICameraID,
                ASICameraDll2.ASI_CONTROL_TYPE.ASI_EXPOSURE
            );
            m_iCurrentWBB = ASICameraDll2.ASIGetControlValue(
                ICameraID,
                ASICameraDll2.ASI_CONTROL_TYPE.ASI_WB_B
            );
            m_iCurrentWBR = ASICameraDll2.ASIGetControlValue(
                ICameraID,
                ASICameraDll2.ASI_CONTROL_TYPE.ASI_WB_R
            );

            m_iCurrentBandWidth = ASICameraDll2.ASIGetControlValue(
                ICameraID,
                ASICameraDll2.ASI_CONTROL_TYPE.ASI_BANDWIDTHOVERLOAD
            );
            m_iTemperature = ASICameraDll2.ASIGetControlValue(
                ICameraID,
                ASICameraDll2.ASI_CONTROL_TYPE.ASI_TEMPERATURE
            );

            int startx = 0,
                starty = 0;
            m_iBin = 1;
            err = ASICameraDll2.ASISetROIFormat(
                ICameraID,
                CamInfoTemp.MaxWidth,
                CamInfoTemp.MaxHeight,
                m_iBin,
                m_imgType
            );
            if (err != ASICameraDll2.ASI_ERROR_CODE.ASI_SUCCESS)
            {
                return false;
            }
            else
            {
                ASICameraDll2.ASISetStartPos(ICameraID, startx, starty);
                ASICameraDll2.ASIGetStartPos(ICameraID, out startx, out starty);
            }

            return true;
        }

        public bool open()
        {
            if (!cameraInit())
            {
                m_bIsOpen = false;
                return false;
            }
            m_bIsOpen = true;
            return true;
        }

        public bool close()
        {
            ASICameraDll2.ASI_ERROR_CODE err = ASICameraDll2.ASICloseCamera(ICameraID);
            if (err != ASICameraDll2.ASI_ERROR_CODE.ASI_SUCCESS)
                return false;
            stopCapture();
            m_bIsOpen = false;
            return true;
        }

        public void startCapture()
        {
            if (!m_bIsOpen)
                return;

            if (m_CaptureMode == CaptureMode.Video)
            {
                ASICameraDll2.ASIStartVideoCapture(ICameraID);
                startCaptureThread();
            }
            else if (m_CaptureMode == CaptureMode.Snap)
            {
                startCaptureThread();
            }
        }

        public void stopCapture()
        {
            if (!m_bIsOpen)
                return;
            if (m_CaptureMode == CaptureMode.Video)
            {
                stopCaptureThread();
                ASICameraDll2.ASIStopVideoCapture(ICameraID);
            }
            else if (m_CaptureMode == CaptureMode.Snap)
            {
                stopCaptureThread();
            }
        }

        public void switchMode(CaptureMode mode)
        {
            m_CaptureMode = mode;
        }

        public bool getControlValue(ASICameraDll2.ASI_CONTROL_TYPE type, out int iValue)
        {
            iValue = ASICameraDll2.ASIGetControlValue(ICameraID, type);
            return true;
        }

        public string scan()
        {
            int cameraNum = ASICameraDll2.ASIGetNumOfConnectedCameras();
            // Consider only one camera connection
            if (cameraNum > 0)
            {
                ASICameraDll2.ASI_CAMERA_INFO camInfoTemp;
                ASICameraDll2.ASIGetCameraProperty(out camInfoTemp, 0);
                m_cameraName = camInfoTemp.Name;

                ICameraID = camInfoTemp.CameraID;
                m_cameraName = camInfoTemp.Name;
                m_iMaxWidth = camInfoTemp.MaxWidth;
                m_iMaxHeight = camInfoTemp.MaxHeight;
                m_bIsColor =
                    camInfoTemp.IsColorCam == ASICameraDll2.ASI_BOOL.ASI_TRUE ? true : false;
                m_bIsCooler =
                    camInfoTemp.IsCoolerCam == ASICameraDll2.ASI_BOOL.ASI_TRUE ? true : false;
                m_bIsUSB3 =
                    camInfoTemp.IsUSB3Camera == ASICameraDll2.ASI_BOOL.ASI_TRUE ? true : false;
                m_bIsUSB3Host =
                    camInfoTemp.IsUSB3Host == ASICameraDll2.ASI_BOOL.ASI_TRUE ? true : false;
            }
            else
            {
                m_cameraName = "";
            }
            return m_cameraName;
        }

        // Capture thread
        public void startCaptureThread()
        {
            if (!m_bThreadRunning)
            {
                m_bThreadStop = false;
                captureThread.Start();
            }
            else
            {
                m_bThreadStop = false;
            }
        }

        public void stopCaptureThread()
        {
            m_bThreadStop = true;
        }

        public void exitCaptureThread()
        {
            m_bThreadExit = true;
        }
        #endregion

        #region RefreshUI delegate
        // RefreshUI delegate
        public delegate void RefreshUICallBack(Bitmap bmp);
        public delegate void RefreshHistogramCallBack(Bitmap bmp);
        public delegate void RefreshCaptureCallBack(Bitmap bmp, uint flag);
        private RefreshHistogramCallBack RefreshHistogram;
        private RefreshUICallBack RefreshUI;
        private RefreshCaptureCallBack RefreshCapture;
        private bool m_bThreadRunning = false;
        private bool m_bThreadStop = false;
        private bool m_bThreadExit = false;

        //hist
        IntPtr buffer = IntPtr.Zero;
        static int histogram_width = 270;
        static int histogram_height = 100;
        static int offset_y = 15;
        Mat hist = new Mat();

        public void SetRefreshUICallBack(RefreshUICallBack callBack)
        {
            RefreshUI = callBack;
        }

        public void SetRefreshHistogramCallBack(RefreshHistogramCallBack callBack)
        {
            RefreshHistogram = callBack;
        }

        public void SetRefreshCaptureCallBack(RefreshCaptureCallBack callBack)
        {
            RefreshCapture = callBack;
        }

        // MessageBox delegate
        public delegate void MessageBoxCallBack(string str, int iVal = 0);
        private MessageBoxCallBack PopupMessageBox;

        public double Min_hist
        {
            get => min_hist;
            set => min_hist = value;
        }
        public double Max_hist
        {
            get => max_hist;
            set => max_hist = value;
        }
        public double Mean_hist
        {
            get => mean_hist;
            set => mean_hist = value;
        }
        public double Std_hist
        {
            get => std_hist;
            set => std_hist = value;
        }

        public string SelectedFolderPath
        {
            get => selectedFolderPath;
            set => selectedFolderPath = value;
        }
        public static string Datetime
        {
            get => datetime;
            set => datetime = value;
        }
        public string File_name
        {
            get => file_name;
            set => file_name = value;
        }
        public ASICameraDll2.ASI_IMG_TYPE ImgType
        {
            get => m_imgType;
            set => m_imgType = value;
        }

        public int Best_exp
        {
            get => best_exp;
            set => best_exp = value;
        }
        public Mat Save_mat
        {
            get => save_mat;
            set => save_mat = value;
        }
        public int ICameraID
        {
            get => m_iCameraID;
            set => m_iCameraID = value;
        }
        public int Cur_exp_ms
        {
            get => cur_exp_ms;
            set => cur_exp_ms = value;
        }

        public void SetMessageBoxCallBack(MessageBoxCallBack callBack)
        {
            PopupMessageBox = callBack;
        }
        #endregion
        #region Class Camera DIY Function
        public bool setControlValue(
            ASICameraDll2.ASI_CONTROL_TYPE type,
            int value,
            ASICameraDll2.ASI_BOOL bAuto
        )
        {
            SemaphoreHolder.rwLock.EnterReadLock();
            if (type == ASICameraDll2.ASI_CONTROL_TYPE.ASI_EXPOSURE)
            {
                m_expMs = value;
            }
            else if (type == ASICameraDll2.ASI_CONTROL_TYPE.ASI_GAIN)
            {
                m_gain = value;
            }
            SemaphoreHolder.is_changed = true;
            SemaphoreHolder.rwLock.ExitReadLock();
            return true;
        }

        public bool setImageFormat(
            int width,
            int height,
            int startx,
            int starty,
            int bin,
            ASICameraDll2.ASI_IMG_TYPE type
        )
        {
            if (!SemaphoreHolder.is_ui_init)
            {
                bool bCanStartThread = false;
                if (!m_bThreadStop && m_bThreadRunning)
                {
                    stopCapture();
                    bCanStartThread = true;
                }

                ASICameraDll2.ASI_ERROR_CODE err = ASICameraDll2.ASISetROIFormat(
                    ICameraID,
                    width,
                    height,
                    bin,
                    type
                );
                if (err != ASICameraDll2.ASI_ERROR_CODE.ASI_SUCCESS)
                {
                    PopupMessageBox("SetFormat Error: " + err.ToString());
                    return false;
                }

                m_iCurWidth = width;
                m_iCurHeight = height;
                m_iSize = m_iMaxWidth * m_iMaxHeight;
                m_iBin = bin;
                m_imgType = type;

                if (bCanStartThread)
                {
                    startCapture();
                }

                return true;
            }
            else
            {
                m_iCurWidth = width;
                m_iCurHeight = height;
                m_iSize = m_iMaxWidth * m_iMaxHeight;
                m_iBin = bin;
                m_imgType = type;

                SemaphoreHolder.is_changed = true;
                return true;
            }
        }
        #endregion

        #region Video Thread
        public void run()
        {
            m_bThreadRunning = true;

            while (true)
            {
                if (m_bThreadExit)
                {
                    break;
                }
                if (m_bThreadStop)
                {
                    continue;
                }
                int cameraID,
                    width,
                    height,
                    buffersize;

                if (SemaphoreHolder.is_changed)
                {
                    ASICameraDll2.ASISetControlValue(
                        ICameraID,
                        ASICameraDll2.ASI_CONTROL_TYPE.ASI_EXPOSURE,
                        cur_exp_ms
                    );
                    ASICameraDll2.ASISetControlValue(
                        ICameraID,
                        ASICameraDll2.ASI_CONTROL_TYPE.ASI_GAIN,
                        cur_gain
                    );
                    ASICameraDll2.ASISetROIFormat(
                        ICameraID,
                        m_iCurWidth,
                        m_iCurHeight,
                        0,
                        cur_type
                    );
                    SemaphoreHolder.is_changed = false;
                    SemaphoreHolder.is_changed_ok = true;
                }

                get_buffersize(out cameraID, out width, out height, out buffersize);
                buffer = Marshal.AllocCoTaskMem(buffersize);

                if (m_CaptureMode == CaptureMode.Video)
                {
                    // cost: 1s
                    // 此处更新新的图片

                    ASICameraDll2.ASI_ERROR_CODE err = get_video_data(cameraID, buffersize);

                    if (err == ASICameraDll2.ASI_ERROR_CODE.ASI_SUCCESS)
                    {
                        // 此处更新hist和
                        byte[] byteArray = copy_buffer(width, height, buffersize);
                        // 防止auto时led强度值与图片不匹配
                        if (SemaphoreHolder.is_received_auto)
                        {
                            SemaphoreHolder.is_received_auto = false;
                            SemaphoreHolder.is_confirmed_auto = true;
                            continue;
                        }
                        get_save_mat(width, height, byteArray);

                        Bitmap bmp = byte_to_bitmap(width, height, byteArray);
                        // cost: 3ms
                        RefreshUI(bmp);
                        // cost: 34ms
                        RefreshHistogram(updateHistogram(hist));

                        // 手动保存图片
                        if (SemaphoreHolder.is_manual)
                        {
                            RefreshCapture(bmp, 4);
                            SemaphoreHolder.is_manual = false;
                        }
                        else if (SemaphoreHolder.is_confirmed_auto)
                        {
                            RefreshCapture(bmp, 5);
                            SemaphoreHolder.is_confirmed_auto = false;
                            SemaphoreHolder.is_updated_auto = true;
                        }
                    }
                    else
                    {
                        // 及时释放防止内存泄露
                        Marshal.FreeCoTaskMem(buffer);
                    }
                    // 全部更新完后再置0，因为太早false得到的灰度值不是最新的
                    if (SemaphoreHolder.is_changed_ok)
                    {
                        SemaphoreHolder.is_changed_ok = false;
                        SemaphoreHolder.is_hist_updated = true;
                    }
                }
                // 一齐保存：（原子操作）存储下一个将要改变的变量
                SemaphoreHolder.rwLock.EnterWriteLock();
                cur_type = m_imgType;
                cur_exp_ms = m_expMs;
                cur_gain = m_gain;
                //Thread.Sleep(500);
                SemaphoreHolder.rwLock.ExitWriteLock();
            }
        }

        ASICameraDll2.ASI_ERROR_CODE get_video_data(int cameraID, int buffersize)
        {
            int expMs = ASICameraDll2.ASIGetControlValue(
                cameraID,
                ASICameraDll2.ASI_CONTROL_TYPE.ASI_EXPOSURE
            );
            expMs /= 1000;
            ASICameraDll2.ASI_ERROR_CODE err = ASICameraDll2.ASI_ERROR_CODE.ASI_ERROR_INVALID_ID;
            // Cost: 1.1s
            // 这里要不要 i = 5有待商榷！！！不i < 5的话会得不到真实的曝光
            for (int i = 0; i < SemaphoreHolder.get_video_count; i++)
            {
                //Thread.Sleep(expMs);
                err = ASICameraDll2.ASIGetVideoData(cameraID, buffer, buffersize, expMs * 2 + 500);
            }

            return err;
        }

        #region Video Thread Internal Function
        Bitmap byte_to_bitmap(int width, int height, byte[] byteArray)
        {
            Bitmap bmp = new Bitmap(width, height);
            int index = 0;

            var lockBitmap = new LockBitmap(bmp);
            lockBitmap.LockBits();
            for (int i = 0; i < height; i++)
            {
                for (int j = 0; j < width; j++)
                {
                    ASICameraDll2.ASIGetROIFormat(
                        ICameraID,
                        out m_iCurWidth,
                        out m_iCurHeight,
                        out m_iBin,
                        out cur_type
                    );

                    if (
                        cur_type == ASICameraDll2.ASI_IMG_TYPE.ASI_IMG_RAW8
                        || cur_type == ASICameraDll2.ASI_IMG_TYPE.ASI_IMG_Y8
                    )
                    {
                        lockBitmap.SetPixel(
                            j,
                            i,
                            Color.FromArgb(byteArray[index], byteArray[index], byteArray[index])
                        );
                    }
                    else if (cur_type == ASICameraDll2.ASI_IMG_TYPE.ASI_IMG_RAW16)
                    {
                        lockBitmap.SetPixel(
                            j,
                            i,
                            Color.FromArgb(
                                byteArray[index * 2 + 1],
                                byteArray[index * 2 + 1],
                                byteArray[index * 2 + 1]
                            )
                        );
                    }
                    else if (cur_type == ASICameraDll2.ASI_IMG_TYPE.ASI_IMG_RGB24)
                    {
                        lockBitmap.SetPixel(
                            j,
                            i,
                            Color.FromArgb(
                                byteArray[index * 3 + 0],
                                byteArray[index * 3 + 1],
                                byteArray[index * 3 + 2]
                            )
                        );
                    }

                    index++;
                }
            }
            lockBitmap.UnlockBits();
            return bmp;
        }

        byte[] copy_buffer(int width, int height, int buffersize)
        {
            if (cur_type == ASICameraDll2.ASI_IMG_TYPE.ASI_IMG_RAW8)
            {
                Mat buffer_mat = new Mat(height, width, MatType.CV_8UC1, buffer);
                Cv2.CalcHist(
                    new Mat[] { buffer_mat },
                    new int[] { 0 },
                    new Mat(),
                    hist,
                    1,
                    new int[] { 256 },
                    new Rangef[] { new Rangef(0, 256) },
                    uniform: true
                );
                Scalar mean_scalar,
                    std_scalar;
                Cv2.MinMaxLoc(buffer_mat, out min_hist, out max_hist);
                Cv2.MeanStdDev(buffer_mat, out mean_scalar, out std_scalar);
                mean_hist = mean_scalar[0];
                std_hist = std_scalar[0];
            }
            else if (cur_type == ASICameraDll2.ASI_IMG_TYPE.ASI_IMG_RAW16)
            {
                int expMs = ASICameraDll2.ASIGetControlValue(
                    ICameraID,
                    ASICameraDll2.ASI_CONTROL_TYPE.ASI_EXPOSURE
                );
                Mat buffer_mat = new Mat(height, width, MatType.CV_16UC1, buffer);
                Cv2.CalcHist(
                    new Mat[] { buffer_mat },
                    new int[] { 0 },
                    new Mat(),
                    hist,
                    1,
                    new int[] { 65536 },
                    new Rangef[] { new Rangef(0, 65536) },
                    uniform: true
                );
                Scalar mean_scalar,
                    std_scalar;
                Cv2.MinMaxLoc(buffer_mat, out min_hist, out max_hist);
                Cv2.MeanStdDev(buffer_mat, out mean_scalar, out std_scalar);
                mean_hist = mean_scalar[0];
                std_hist = std_scalar[0];
            }
            byte[] byteArray = new byte[buffersize];
            Marshal.Copy(buffer, byteArray, 0, buffersize);

            Marshal.FreeCoTaskMem(buffer);
            return byteArray;
        }

        void get_buffersize(out int cameraID, out int width, out int height, out int buffersize)
        {
            cameraID = ICameraID;
            width = m_iCurWidth;
            height = m_iCurHeight;
            buffersize = 0;
            if (
                cur_type == ASICameraDll2.ASI_IMG_TYPE.ASI_IMG_RAW8
                || cur_type == ASICameraDll2.ASI_IMG_TYPE.ASI_IMG_Y8
            )
                buffersize = width * height;
            if (cur_type == ASICameraDll2.ASI_IMG_TYPE.ASI_IMG_RAW16)
                buffersize = width * height * 2;
            if (cur_type == ASICameraDll2.ASI_IMG_TYPE.ASI_IMG_RGB24)
                buffersize = width * height * 3;
        }

        Bitmap updateHistogram(Mat hist)
        {
            Mat histogram = new Mat(
                histogram_height,
                histogram_width,
                MatType.CV_8UC3,
                new Scalar(255, 255, 255)
            );
            if (cur_type == ASICameraDll2.ASI_IMG_TYPE.ASI_IMG_RAW8)
            {
                int bin_w = (int)Math.Round((double)histogram_width / 256);
                Cv2.Normalize(
                    hist,
                    hist,
                    0,
                    histogram.Rows - offset_y,
                    NormTypes.MinMax,
                    -1,
                    new Mat()
                );

                for (int i = 1; i < 256; i++)
                {
                    Cv2.Line(
                        histogram,
                        new OpenCvSharp.Point(
                            bin_w * (i - 1),
                            histogram_height - offset_y - (int)Math.Round(hist.At<float>(0, i - 1))
                        ),
                        new OpenCvSharp.Point(
                            bin_w * i,
                            histogram_height - offset_y - (int)Math.Round(hist.At<float>(0, i))
                        ),
                        new Scalar(0, 0, 0),
                        2,
                        LineTypes.Link8,
                        0
                    );
                }
                Cv2.PutText(
                    histogram,
                    "0",
                    new OpenCvSharp.Point(0, histogram_height - 20),
                    HersheyFonts.HersheySimplex,
                    0.3,
                    new Scalar(0, 0, 0),
                    1
                );
                int step = 250 / 5;
                for (int i = 1; i < 5; i++)
                {
                    int value = i * step;
                    string label = value.ToString();
                    Cv2.PutText(
                        histogram,
                        label,
                        new OpenCvSharp.Point(bin_w * (i * step), histogram_height - 20),
                        HersheyFonts.HersheySimplex,
                        0.3,
                        new Scalar(0, 0, 0),
                        1
                    );
                }
                Cv2.PutText(
                    histogram,
                    "255",
                    new OpenCvSharp.Point(256, histogram_height - 20),
                    HersheyFonts.HersheySimplex,
                    0.3,
                    new Scalar(0, 0, 0),
                    1
                );
            }
            else if (cur_type == ASICameraDll2.ASI_IMG_TYPE.ASI_IMG_RAW16)
            {
                int bin_w = (int)Math.Round((double)histogram_width / 256);
                int sampleStep = 65536 / 256;
                Mat sampledHist = new Mat(256, 1, MatType.CV_32FC1);

                for (int i = 0; i < 256; i++)
                {
                    float sum = 0;
                    for (int j = 0; j < sampleStep; j++)
                    {
                        sum += hist.At<float>(i * sampleStep + j);
                    }
                    sampledHist.Set<float>(i, 0, sum / sampleStep);
                }

                Cv2.Normalize(
                    sampledHist,
                    sampledHist,
                    0,
                    sampledHist.Rows - offset_y,
                    NormTypes.MinMax,
                    -1,
                    null
                );

                for (int i = 1; i < 256; i++)
                {
                    Cv2.Line(
                        histogram,
                        new OpenCvSharp.Point(
                            bin_w * (i - 1),
                            histogram_height
                                - offset_y
                                - (int)Math.Round(sampledHist.At<float>(0, i - 1))
                        ),
                        new OpenCvSharp.Point(
                            bin_w * i,
                            histogram_height
                                - offset_y
                                - (int)Math.Round(sampledHist.At<float>(0, i))
                        ),
                        new Scalar(0, 0, 0),
                        2,
                        LineTypes.Link8,
                        0
                    );
                }
                Cv2.PutText(
                    histogram,
                    "0",
                    new OpenCvSharp.Point(0, histogram_height - 20),
                    HersheyFonts.HersheySimplex,
                    0.3,
                    new Scalar(0, 0, 0),
                    1
                );
                int step = 250 / 5;
                for (int i = 1; i < 5; i++)
                {
                    int value = i * (65535 / 5);
                    string label = value.ToString();
                    Cv2.PutText(
                        histogram,
                        label,
                        new OpenCvSharp.Point(bin_w * (i * step), histogram_height - 20),
                        HersheyFonts.HersheySimplex,
                        0.3,
                        new Scalar(0, 0, 0),
                        1
                    );
                }
                Cv2.PutText(
                    histogram,
                    "65535",
                    new OpenCvSharp.Point(256, histogram_height - 20),
                    HersheyFonts.HersheySimplex,
                    0.3,
                    new Scalar(0, 0, 0),
                    1
                );
            }
            return new Bitmap(OpenCvSharp.Extensions.BitmapConverter.ToBitmap(histogram));
        }

        void get_save_mat(int width, int height, byte[] byteArray)
        {
            if (cur_type == ASICameraDll2.ASI_IMG_TYPE.ASI_IMG_RAW8)
            {
                save_mat = new Mat(height, width, MatType.CV_8UC1, byteArray);
            }
            else if (cur_type == ASICameraDll2.ASI_IMG_TYPE.ASI_IMG_RAW16)
            {
                save_mat = new Mat(height, width, MatType.CV_16UC1, byteArray);
            }
        }
        #endregion

        #endregion
    }
}
