using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Data;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Imaging;
using System.Globalization;
using System.IO;
using System.IO.Ports;
using System.Linq;
using System.Runtime.ConstrainedExecution;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading;
using System.Windows.Forms;
using LiveCharts;
using LiveCharts.Wpf;
using NetOceanDirect;
using OpenCvSharp;
using ZWOptical.ASISDK;

namespace ASICamera_demo
{
    public partial class Form2 : Form
    {
        #region data struct
        /*保存日志*/
        public static string log;
        public static string log_meter;

        // camera object
        private Camera m_camera = new Camera();
        private Meter meter = new();

        // first Open
        private bool m_isFirstOpen = true;

        // last bin value
        private int m_iLastBin = 1;
        private System.Windows.Forms.Label[] ledLabels = new System.Windows.Forms.Label[16];
        System.Windows.Forms.NumericUpDown[] ledSpinBoxs = new System.Windows.Forms.NumericUpDown[
            16
        ];

        // 自动曝光调整因子α, β
        private double alpha = 1;

        // led阵列
        LedArray led_array = new LedArray();

        /*串口*/
        List<byte> byteBuffer = new List<byte>(); //接收字节缓存区
        string receiveMode = "HEX模式";
        string sendMode = "HEX模式";
        string sendCoding = "GBK";
        #endregion

        CmeMoCtrl ser;
        double zeroPosition, correctionCoefficient, totalSteps;
        #region constructor
        private void Form2_Load(object sender, EventArgs e) //窗口加载事件
        {
            /**/
            // 或者直接设置窗体状态为最大化（如果不需要隐藏任务栏）
            this.WindowState = FormWindowState.Normal;
            cbBaudRate.SelectedIndex = 4; //控件状态初始化
            cbDataBits.SelectedIndex = 3;
            cbStopBits.SelectedIndex = 0;
            cbParity.SelectedIndex = 0;
            cbReceiveMode.SelectedIndex = 0;
            cbReceiveCoding.SelectedIndex = 0;
            cbSendMode.SelectedIndex = 0;
            cbSendCoding.SelectedIndex = 0;
            btnSend.Enabled = false;
            cbPortName.Enabled = true;
            cbBaudRate.Enabled = true;
            cbDataBits.Enabled = true;
            cbStopBits.Enabled = true;
            cbParity.Enabled = true;
            /*LED Label Array*/
            ledLabels[0] = label24;
            ledLabels[1] = label25;
            ledLabels[2] = label26;
            ledLabels[3] = label27;
            ledLabels[4] = label28;
            ledLabels[5] = label29;
            ledLabels[6] = label30;
            ledLabels[7] = label31;
            ledLabels[8] = label32;
            ledLabels[9] = label33;
            ledLabels[10] = label34;
            ledLabels[11] = label35;
            ledLabels[12] = label36;
            ledLabels[13] = label37;
            ledLabels[14] = label38;
            ledLabels[15] = label39;
            /*LED SpinBox Array*/
            ledSpinBoxs[0] = numericUpDown1;
            ledSpinBoxs[1] = numericUpDown2;
            ledSpinBoxs[2] = numericUpDown3;
            ledSpinBoxs[3] = numericUpDown4;
            ledSpinBoxs[4] = numericUpDown5;
            ledSpinBoxs[5] = numericUpDown6;
            ledSpinBoxs[6] = numericUpDown7;
            ledSpinBoxs[7] = numericUpDown8;
            ledSpinBoxs[8] = numericUpDown9;
            ledSpinBoxs[9] = numericUpDown10;
            ledSpinBoxs[10] = numericUpDown11;
            ledSpinBoxs[11] = numericUpDown12;
            ledSpinBoxs[12] = numericUpDown13;
            // 此处过于粗心导致出错!!
            //ledSpinBoxs[13] = numericUpDown14;
            //ledSpinBoxs[14] = numericUpDown14;
            ledSpinBoxs[13] = numericUpDown14;
            ledSpinBoxs[14] = numericUpDown15;
            ledSpinBoxs[15] = numericUpDown16;
            for (int i = 0; i < 16; i++)
            {
                ledLabels[i].Text = "LED" + (i + 1);
                ledSpinBoxs[i].Maximum = 100;
                ledSpinBoxs[i].Minimum = 0;
                ledSpinBoxs[i].Value = 0;
                numericUpDown17.Value = 100;
                numericUpDown17.Increment = 100;
                numericUpDown17.Maximum = 100;
                numericUpDown17.Minimum = 1;
                ledSpinBoxs[i].Increment = numericUpDown17.Value;
                led_array.Value[i] = (byte)ledSpinBoxs[i].Value;
                ledSpinBoxs[i].ValueChanged += UpdateLED;
                ledSpinBoxs[i].Enabled = true;
            }
            ledSpinBoxs[1].Value = 100;
            // 开启程序后默认打开相机
            button_open.PerformClick();
            // 开启后默认打开搜索串口号并打开打开最后一个找到的串口"COM6"，固定为CH340
            string[] names = System.IO.Ports.SerialPort.GetPortNames(); //搜索可用串口号并添加到下拉列表
            cbPortName.Items.Clear();
            cbPortName.Items.AddRange(names);
            cbPortName.Text = cbPortName.Items[cbPortName.Items.Count - 1].ToString();
            OpenSerialPort();

        }

        LineSeries lineSeries = new LineSeries
        {
            PointGeometrySize = 10,
            //PointGeometry = DefaultGeometries.Circle,
            PointGeometry = null, // 移除数据点标记
        };
        static (CmeMoCtrl, double, double, double) CmeMoInit(string portId = "COM9")
        {
            CmeMoCtrl ser = new CmeMoCtrl(portName: portId);
            var connectionInfo = ser.CheckConnection();
            Console.WriteLine($"Connection Info: {connectionInfo}");

            ser.StartParameterQuery();  // 开始参数查询进程

            var systemParams = ser.QuerySystemParameters();
            double totalSteps = Convert.ToDouble(((dynamic)systemParams).TotalSteps);

            if (systemParams != null)
            {
                Console.WriteLine($"System Parameters: {systemParams}");
            }

            int gratingGroup = 0;  // 光栅组编号
            int gratingNumber = 1;  // 光栅编号
            var gratingParams = ser.QueryGratingParameters(gratingGroup, gratingNumber);

            if (gratingParams != null)
            {
                Console.WriteLine($"Grating Parameters: {gratingParams}");
            }

            var filterGroupInfo = ser.QueryFilterGroup();
            if (filterGroupInfo != null)
            {
                Console.WriteLine($"Filter Group Info: {filterGroupInfo}");
            }

            var filterWorkingRange = ser.QueryFilterWorkingRange(1, 8);  // 查询光栅编号1，返回8个滤光片信息
            if (filterWorkingRange != null)
            {
                Console.WriteLine($"Filter Working Range: {filterWorkingRange}");
            }

            var gratingSwitchPosition = ser.QueryGratingSwitchPosition();  // 查询光栅切换位置
            if (gratingSwitchPosition != null)
            {
                Console.WriteLine($"Grating Switch Position: {gratingSwitchPosition}");
            }

            string parallelExitPosition = ser.QueryParallelExitPosition();  // 查询双出口的1出口定位基准值
            if (parallelExitPosition != null)
            {
                Console.WriteLine($"Parallel Exit Position: {parallelExitPosition}");
            }

            var exitAutoSwitchWavelength = ser.QueryExitAutoSwitchWavelength();  // 查询出口自动切换波长
            if (exitAutoSwitchWavelength != null)
            {
                Console.WriteLine($"Exit Auto Switch Wavelength: {exitAutoSwitchWavelength}");
            }

            double zeroPosition = Convert.ToDouble(((dynamic)gratingParams).ZeroPosition);
            double correctionCoefficient = Convert.ToDouble(((dynamic)gratingParams).CorrectionCoefficient);

            Console.WriteLine($"Zero Position (Z): {zeroPosition}, Correction Coefficient (C): {correctionCoefficient}");

            ser.EndParameterQuery();  // 结束参数查询进程

            // ser.Reposition();  // 重新定位
            // Thread.Sleep(3000);

            Console.WriteLine($"Current Position: {ser.QueryCurrentPosition()}");  // 查询当前位置
            Console.WriteLine($"Current Grating: {ser.QueryCurrentGrating()}");  // 查询当前光栅

            return (ser, zeroPosition, correctionCoefficient, totalSteps);
        }
        // Constructor
        public Form2()
        {
            InitializeComponent();
            Font newFont = new Font("微软雅黑", 8);
            this.Font = newFont;
            // Connect after opening the software
            string strCameraName = m_camera.scan();
            if (strCameraName != "")
            {
                comboBox_cameraName.Items.Add(strCameraName);
                comboBox_cameraName.SelectedIndex = 0;

                button_open.Enabled = true;
                label_cameraInfo.Visible = true;
                label_temperature.Visible = true;
            }
            meter.SetRefreshDataCallBack(RefreshData);
            // Set the callback of UI refresh delegation
            m_camera.SetRefreshUICallBack(RefreshUI);
            m_camera.SetRefreshHistogramCallBack(RefreshHistogram);
            m_camera.SetRefreshCaptureCallBack(RefreshCapture);
            m_camera.SetMessageBoxCallBack(PopupMessageBox);
            save_path_label.Text = "Save Dir: \n ./" + Camera.Datetime;
            if (!Directory.Exists(m_camera.SelectedFolderPath))
            {
                Directory.CreateDirectory(m_camera.SelectedFolderPath);
            }
            log +=
                "Save Dir: "
                + m_camera.SelectedFolderPath
                + "\n"
                + "Date: "
                + Camera.Datetime
                + "\n"
                + "\t=======================================\t"
                + "\n";

            var SeriesCollection = new SeriesCollection { lineSeries };
            cartesianChart1.Series = SeriesCollection;
        }
        #endregion
        #region Delagation Declartion
        private delegate void DisplayDataCallback(int flag);

        private void DisplayData(int flag)
        {
            if (flag == 0)
            {
                cartesianChart1.DisableAnimations = true;
                ChartValues<double> yAxisValues = new ChartValues<double>(meter.Spectrum);
                if (meter.count == 0)
                {
                    meter.count++;
                    var xAxisValues = new ChartValues<double>();

                    for (double i = 400; i <= 700; i++)
                    {
                        xAxisValues.Add(i);
                    }
                    // 设置X轴，指定标签
                    var axisX = new Axis
                    {
                        Title = "X Axis",
                        Labels = xAxisValues.Select(x => x.ToString()).ToList(),
                        Separator = new Separator
                        {
                            Step = 100,
                        } // 显示所有标签
                        ,
                    };
                    cartesianChart1.AxisX.Clear();
                    cartesianChart1.AxisX.Add(axisX);
                    // 设置Y轴
                    var axisY = new Axis
                    {
                        Title = "Y Axis",
                        MinValue = 0, // 设置最小值为0
                        MaxValue = 200000, // 设置最大值为20万
                        LabelFormatter = value => value.ToString("N"),
                    };
                    cartesianChart1.AxisY.Clear();
                    cartesianChart1.AxisY.Add(axisY);

                    // 有频闪看看如何解决
                    lineSeries.Values = yAxisValues;
                    // 创建一个LineSeries对象，并将y轴数据赋给它
                    //var lineSeries = new LineSeries
                    //{
                    //    Values = yAxisValues,
                    //    PointGeometrySize = 10,
                    //    PointGeometry = DefaultGeometries.Circle,
                    //};

                    // 添加系列到集合中
                }
                // 创建一个线性序列，代表横坐标从400到700，步长为10
                //ChartValues<double> yAxisValues = new ChartValues<double>(meter.Spectrum);
                lineSeries.Values = yAxisValues;
            }
            else if (flag == 1)
            {
                ud_meter_cur_index.Value++;
                SemaphoreHolder.is_save_meter = false;
                for (int i = 0; i < meter.Spectrum.Length; i++)
                {
                    log_meter += Math.Round(meter.Spectrum[i]) + "\n";
                }
                int errcode = 0;
                // get曝光时间
                var itime = meter.Ocean.getIntegrationTimeMicros(meter.DeviceID, ref errcode);
                try
                {
                    File.WriteAllText(
                        m_camera.SelectedFolderPath
                            + "/"
                            + led_array.Selected_index
                            + "_"
                            + tb_name_meter.Text
                            + ud_meter_cur_index.Value
                            + "_"
                            + itime
                            + ".txt",
                        log_meter
                    );
                    log_meter = "";
                }
                catch (Exception ex)
                {
                    Console.WriteLine("保存文件时出错: " + ex.Message);
                }
            }
        }

        public void RefreshData(int flag)
        {
            if (this.InvokeRequired)
            {
                DisplayDataCallback displayData = new DisplayDataCallback(DisplayData);
                this.Invoke(displayData, new object[] { flag });
            }
            else
            {
                DisplayData(flag);
            }
        }

        public void RefreshUI(Bitmap bmp)
        {
            if (this.InvokeRequired)
            {
                DisplayUICallback displayUI = new DisplayUICallback(DisplayUI);
                this.Invoke(displayUI, new object[] { bmp });
            }
            else
            {
                DisplayUI(bmp);
            }
        }

        public void RefreshHistogram(Bitmap bmp)
        {
            if (this.InvokeRequired)
            {
                DisplayHistogramCallback displayHistogram = new DisplayHistogramCallback(
                    DisplayHistogram
                );
                this.Invoke(displayHistogram, new object[] { bmp });
            }
            else
            {
                DisplayHistogram(bmp);
            }
        }

        public void RefreshCapture(Bitmap bmp, uint flag)
        {
            if (this.InvokeRequired)
            {
                DisplayCaptureCallback displayCapture = new DisplayCaptureCallback(DisplayCapture);
                this.Invoke(displayCapture, new object[] { bmp, flag });
            }
            else
            {
                DisplayCapture(bmp, flag);
            }
        }

        private delegate void DisplayUICallback(Bitmap bmp);
        private delegate void DisplayHistogramCallback(Bitmap bmp);
        private delegate void DisplayCaptureCallback(Bitmap bmp, uint flag);
        #endregion

        #region default function

        public void PopupMessageBox(string str, int iVal)
        {
            if (this.InvokeRequired)
            {
                PopMessageBoxCallback PopupMessageBox = new PopMessageBoxCallback(_PopupMessageBox);
                this.Invoke(PopupMessageBox, new object[] { str, iVal });
            }
            else
            {
                _PopupMessageBox(str, iVal);
            }
        }

        private delegate void PopMessageBoxCallback(string str, int iVal);

        private void _PopupMessageBox(string str, int iVal)
        {
            if (str == "Get Temperature")
            {
                float fTemperature = (float)iVal / 10;
                label_temperature.Text = fTemperature.ToString() + "℃";

                return;
            }

            if (str == "Gain Auto")
            {
                trackBar_gain.Value = iVal;
                spinBox_gain.Value = iVal;
                return;
            }

            if (str == "Exposure Auto")
            {
                if (iVal >= 1000000)
                {
                    iVal = 1000000;
                }
                trackBar_exposure.Value = iVal;
                spinBox_exposure.Value = iVal;
                return;
            }

            if (str == "No Camera Connection")
            {
                button_open.Enabled = false;
                label_cameraInfo.Visible = false;

                comboBox_cameraName.Items.Clear();
                comboBox_cameraName.Text = "";
            }

            MessageBox.Show(str);
        }

        // UI Init
        void UIInit()
        {
            // exposure time : unit us 32->10000
            int currentExpMs = m_camera.getCurrentExpMs();
            // 限制在1000000us，也就是1s
            if (currentExpMs >= 1000000)
                currentExpMs = 1000000;
            trackBar_exposure.Value = currentExpMs;
            spinBox_exposure.Value = currentExpMs;
            // gain
            int maxGain = m_camera.getMaxGain();
            trackBar_gain.Maximum = maxGain;
            spinBox_gain.Maximum = maxGain;
            int currentGain = m_camera.getCurrentGain();
            trackBar_gain.Value = currentGain;
            spinBox_gain.Value = currentGain;
            spinBox_gain.Value = 0;

            comboBox_captureMode.Items.Clear();
            comboBox_captureMode.Items.Add("Video");
            comboBox_captureMode.Items.Add("Snap");
            comboBox_captureMode.SelectedIndex = 0;

            comboBox_imageFormat.Items.Clear();
            ASICameraDll2.ASI_IMG_TYPE[] typeArr = m_camera.getImgTypeArr();
            int index = 0;
            while (typeArr[index] != ASICameraDll2.ASI_IMG_TYPE.ASI_IMG_END)
            {
                string[] list = typeArr[index].ToString().Split('_');
                comboBox_imageFormat.Items.Add(list[2]);
                index++;
            }

            comboBox_resolution.Items.Clear();
            comboBox_bin.Items.Clear();
            int[] binArr = m_camera.getBinArr();
            index = 0;
            while (binArr[index] != 0)
            {
                comboBox_bin.Items.Add("Bin" + binArr[index].ToString());
                int width = m_camera.getMaxWidth() / binArr[index];
                int height = m_camera.getMaxHeight() / binArr[index];
                // 向下圆整
                while (width % 8 != 0)
                {
                    width--;
                }
                while (height % 2 != 0)
                {
                    height--;
                }
                comboBox_resolution.Items.Add(width.ToString() + '*' + height.ToString());
                index++;
            }
            // 默认设置为RAW16
            comboBox_imageFormat.SelectedIndex = 1;
            //string strType = comboBox_imageFormat.SelectedItem.ToString();
            //m_camera.setImageFormat(0, 0, 0, 0, 0, str2Type(strType));

            comboBox_bin.SelectedIndex = 0;
            comboBox_resolution.SelectedIndex = 0;

            comboBox_resolution.Items.Add(Convert.ToString(1600) + '*' + Convert.ToString(900));
            comboBox_resolution.Items.Add(Convert.ToString(1280) + '*' + Convert.ToString(720));
            comboBox_resolution.Items.Add(Convert.ToString(640) + '*' + Convert.ToString(480));
            comboBox_resolution.Items.Add(Convert.ToString(320) + '*' + Convert.ToString(240));
            SemaphoreHolder.is_ui_init = true;
        }

        // refresh UI Enable
        private void refreshUIEnable(bool bEnable)
        {
            comboBox_bin.Enabled = bEnable;
            comboBox_captureMode.Enabled = bEnable;
            comboBox_imageFormat.Enabled = bEnable;
            comboBox_resolution.Enabled = bEnable;

            button_close.Enabled = bEnable;
            button_scan.Enabled = !bEnable;
            button_open.Enabled = !bEnable;

            spinBox_exposure.Enabled = bEnable;
            spinBox_gain.Enabled = bEnable;

            trackBar_exposure.Enabled = bEnable;
            trackBar_gain.Enabled = bEnable;

            checkBox_gainAuto.Enabled = bEnable;
            checkBox_exposureAuto.Enabled = bEnable;
        }

        private void button_open_Click(object sender, EventArgs e)
        {
            if (m_camera.open())
            {
                refreshUIEnable(true);
                if (m_isFirstOpen)
                {
                    UIInit();
                    m_isFirstOpen = false;
                }
                if (comboBox_captureMode.SelectedItem.ToString() == "Video")
                {
                    button_startVideo.Enabled = true;
                    button_snap.Enabled = false;
                }
                else if (comboBox_captureMode.SelectedItem.ToString() == "Snap")
                {
                    button_startVideo.Enabled = false;
                    button_snap.Enabled = true;
                }

                if (comboBox_captureMode.SelectedItem.ToString() == "Video")
                    startVideo();

                // label_SN.Text = "SN: " + m_camera.getSN();

                //gainAuto();
                //exposureAuto();
            }
        }

        private void button_close_Click(object sender, EventArgs e)
        {
            if (m_camera.close())
            {
                refreshUIEnable(false);
                button_startVideo.Enabled = false;
                button_snap.Enabled = false;
                button_startVideo.Text = "StartVideo";
            }
        }

        private void button_startVideo_Click(object sender, EventArgs e)
        {
            startVideo();
        }

        private void startVideo()
        {
            if (button_startVideo.Text == "StartVideo")
            {
                m_camera.startCapture();
                button_startVideo.Text = "StopVideo";
                comboBox_captureMode.Enabled = false;
            }
            else if (button_startVideo.Text == "StopVideo")
            {
                m_camera.stopCapture();
                button_startVideo.Text = "StartVideo";
                comboBox_captureMode.Enabled = true;
            }
        }

        private void button_scan_Click(object sender, EventArgs e)
        {
            string strCameraName = m_camera.scan();
            if (strCameraName != "")
            {
                comboBox_cameraName.Items.Clear();
                comboBox_cameraName.Items.Add(strCameraName);
                comboBox_cameraName.SelectedIndex = 0;

                m_isFirstOpen = true;

                button_open.Enabled = true;
                label_cameraInfo.Visible = true;
            }
            else
            {
                button_open.Enabled = false;
                label_cameraInfo.Visible = false;

                comboBox_cameraName.Items.Clear();
                comboBox_cameraName.Text = "";
            }
        }

        private void button_snap_Click(object sender, EventArgs e)
        {
            m_camera.startCapture();
            comboBox_captureMode.Enabled = false;
        }

        private void comboBox_captureMode_SelectedIndexChanged(object sender, EventArgs e)
        {
            if (comboBox_captureMode.SelectedItem.ToString() == "Video")
            {
                m_camera.switchMode(Camera.CaptureMode.Video);
                button_startVideo.Enabled = true;
                button_snap.Enabled = false;
            }
            else if (comboBox_captureMode.SelectedItem.ToString() == "Snap")
            {
                m_camera.switchMode(Camera.CaptureMode.Snap);
                button_startVideo.Enabled = false;
                button_snap.Enabled = true;
            }
        }

        private void trackBar_gain_Scroll(object sender, EventArgs e)
        {
            if (!trackBar_gain.Enabled)
                return;

            int val = trackBar_gain.Value;
            if (
                m_camera.setControlValue(
                    ASICameraDll2.ASI_CONTROL_TYPE.ASI_GAIN,
                    val,
                    ASICameraDll2.ASI_BOOL.ASI_FALSE
                )
            )
            {
                spinBox_gain.Value = val;
            }
        }

        private void spinBox_gain_ValueChanged(object sender, EventArgs e)
        {
            if (!spinBox_gain.Enabled)
                return;

            int val = (int)spinBox_gain.Value;
            if (
                m_camera.setControlValue(
                    ASICameraDll2.ASI_CONTROL_TYPE.ASI_GAIN,
                    val,
                    ASICameraDll2.ASI_BOOL.ASI_FALSE
                )
            )
            {
                trackBar_gain.Value = val;
            }
        }

        public void getFormatParas(
            out string strType,
            out int iWidth,
            out int iHeight,
            out int iBin
        )
        {
            if (m_isFirstOpen)
            {
                // 默认设置为RAW16
                strType = "RAW16";
                iWidth = m_camera.getMaxWidth();
                iHeight = m_camera.getMaxHeight();
                iBin = 1;
            }
            else
            {
                strType = comboBox_imageFormat.SelectedItem.ToString();

                string[] list = comboBox_resolution.SelectedItem.ToString().Split('*');
                iWidth = Convert.ToInt32(list[0]);
                iHeight = Convert.ToInt32(list[1]);

                iBin = (int)Char.GetNumericValue(comboBox_bin.Text.Last());
            }
            m_iLastBin = iBin;
        }

        private void comboBox_imageFormat_SelectedIndexChanged(object sender, EventArgs e)
        {
            string strType = "";
            int iBin = 0;
            int iWidth = 0;
            int iHeight = 0;
            getFormatParas(out strType, out iWidth, out iHeight, out iBin);
            //SemaphoreHolder.is_changed = true;

            m_camera.setImageFormat(iWidth, iHeight, 0, 0, iBin, str2Type(strType));
        }

        private void comboBox_bin_SelectedIndexChanged(object sender, EventArgs e)
        {
            string strType = "";
            int iBin = 0;
            int iWidth = 0;
            int iHeight = 0;

            int iLastBin = m_iLastBin;
            getFormatParas(out strType, out iWidth, out iHeight, out iBin);
            int iCurBin = m_iLastBin;
            float fRatio = (float)iLastBin / (float)iCurBin;
            float fWidth = (float)iWidth * fRatio;
            float fHeight = (float)iHeight * fRatio;
            iWidth = (int)fWidth;
            iHeight = (int)fHeight;

            // 向下圆整
            while (iWidth % 8 != 0)
            {
                iWidth--;
            }
            while (iHeight % 2 != 0)
            {
                iHeight--;
            }

            m_camera.setImageFormat(iWidth, iHeight, 0, 0, iBin, str2Type(strType));

            int index = comboBox_resolution.Items.IndexOf(
                iWidth.ToString() + '*' + iHeight.ToString()
            );
            if (index != -1)
            {
                comboBox_resolution.SelectedIndex = index;
            }
            else
            {
                string strResolution = iWidth.ToString() + '*' + iHeight.ToString();
                comboBox_resolution.Items.Add(strResolution);
                index = comboBox_resolution.Items.IndexOf(strResolution);
                comboBox_resolution.SelectedIndex = index;
            }
        }

        private void comboBox_resolution_SelectedIndexChanged(object sender, EventArgs e)
        {
            string strType = "";
            int iBin = 0;
            int iWidth = 0;
            int iHeight = 0;
            getFormatParas(out strType, out iWidth, out iHeight, out iBin);

            m_camera.setImageFormat(iWidth, iHeight, 0, 0, iBin, str2Type(strType));
        }

        // method
        public ASICameraDll2.ASI_IMG_TYPE str2Type(string strType)
        {
            if (strType == "RAW8")
            {
                return ASICameraDll2.ASI_IMG_TYPE.ASI_IMG_RAW8;
            }
            else if (strType == "RAW16")
            {
                return ASICameraDll2.ASI_IMG_TYPE.ASI_IMG_RAW16;
            }
            else if (strType == "RGB24")
            {
                return ASICameraDll2.ASI_IMG_TYPE.ASI_IMG_RGB24;
            }
            else
            {
                return ASICameraDll2.ASI_IMG_TYPE.ASI_IMG_Y8;
            }
        }

        private void Form1_FormClosing(object sender, FormClosingEventArgs e)
        {
            m_camera.close();
            m_camera.exitCaptureThread();
        }

        private void trackBar_exposure_Scroll(object sender, EventArgs e)
        {
            if (!trackBar_gain.Enabled)
                return;

            int val = trackBar_exposure.Value;
            spinBox_exposure.Value = val;
            m_camera.setControlValue(
                ASICameraDll2.ASI_CONTROL_TYPE.ASI_EXPOSURE,
                val,
                ASICameraDll2.ASI_BOOL.ASI_TRUE
            );
        }
        #endregion
        #region DIY Function
        #region SerialPort
        private void UpdateLED(object sender, EventArgs e)
        {
            for (int i = 0; i < 16; i++)
            {
                led_array.Value[i] = (byte)ledSpinBoxs[i].Value;
            }
        }

        private string BytesToText(byte[] bytes, string encoding) //字节流转文本
        {
            List<byte> byteDecode = new List<byte>(); //需要转码的缓存区
            byteBuffer.AddRange(bytes); //接收字节流到接收字节缓存区
            if (encoding == "GBK")
            {
                int count = byteBuffer.Count;
                for (int i = 0; i < count; i++)
                {
                    if (byteBuffer.Count == 0)
                    {
                        break;
                    }

                    if (byteBuffer[0] < 0x80) //1字节字符
                    {
                        byteDecode.Add(byteBuffer[0]);
                        byteBuffer.RemoveAt(0);
                    }
                    else //2字节字符
                    {
                        if (byteBuffer.Count >= 2)
                        {
                            byteDecode.Add(byteBuffer[0]);
                            byteBuffer.RemoveAt(0);
                            byteDecode.Add(byteBuffer[0]);
                            byteBuffer.RemoveAt(0);
                        }
                    }
                }
            }
            else if (encoding == "UTF-8")
            {
                int count = byteBuffer.Count;
                for (int i = 0; i < count; i++)
                {
                    if (byteBuffer.Count == 0)
                    {
                        break;
                    }

                    if ((byteBuffer[0] & 0x80) == 0x00) //1字节字符
                    {
                        byteDecode.Add(byteBuffer[0]);
                        byteBuffer.RemoveAt(0);
                    }
                    else if ((byteBuffer[0] & 0xE0) == 0xC0) //2字节字符
                    {
                        if (byteBuffer.Count >= 2)
                        {
                            byteDecode.Add(byteBuffer[0]);
                            byteBuffer.RemoveAt(0);
                            byteDecode.Add(byteBuffer[0]);
                            byteBuffer.RemoveAt(0);
                        }
                    }
                    else if ((byteBuffer[0] & 0xF0) == 0xE0) //3字节字符
                    {
                        if (byteBuffer.Count >= 3)
                        {
                            byteDecode.Add(byteBuffer[0]);
                            byteBuffer.RemoveAt(0);
                            byteDecode.Add(byteBuffer[0]);
                            byteBuffer.RemoveAt(0);
                            byteDecode.Add(byteBuffer[0]);
                            byteBuffer.RemoveAt(0);
                        }
                    }
                    else if ((byteBuffer[0] & 0xF8) == 0xF0) //4字节字符
                    {
                        if (byteBuffer.Count >= 4)
                        {
                            byteDecode.Add(byteBuffer[0]);
                            byteBuffer.RemoveAt(0);
                            byteDecode.Add(byteBuffer[0]);
                            byteBuffer.RemoveAt(0);
                            byteDecode.Add(byteBuffer[0]);
                            byteBuffer.RemoveAt(0);
                            byteDecode.Add(byteBuffer[0]);
                            byteBuffer.RemoveAt(0);
                        }
                    }
                    else //其他
                    {
                        byteDecode.Add(byteBuffer[0]);
                        byteBuffer.RemoveAt(0);
                    }
                }
            }

            return Encoding.GetEncoding(encoding).GetString(byteDecode.ToArray());
        }

        private string BytesToHex(byte[] bytes) //字节流转HEX
        {
            string hex = "";
            foreach (byte b in bytes)
            {
                hex += b.ToString("X2") + " ";
            }

            return hex;
        }

        private byte[] TextToBytes(string str, string encoding) //文本转字节流
        {
            return Encoding.GetEncoding(encoding).GetBytes(str);
        }

        private byte[] HexToBytes(string str) //HEX转字节流
        {
            string str1 = Regex.Replace(str, "[^A-F^a-f^0-9]", ""); //清除非法字符

            double i = str1.Length; //将字符两两拆分
            int len = 2;
            string[] strList = new string[int.Parse(Math.Ceiling(i / len).ToString())];
            for (int j = 0; j < strList.Length; j++)
            {
                len = len <= str1.Length ? len : str1.Length;
                strList[j] = str1.Substring(0, len);
                str1 = str1.Substring(len, str1.Length - len);
            }

            int count = strList.Length; //将拆分后的字符依次转换为字节
            byte[] bytes = new byte[count];
            for (int j = 0; j < count; j++)
            {
                bytes[j] = byte.Parse(strList[j], NumberStyles.HexNumber);
            }

            return bytes;
        }

        private void OpenSerialPort() //打开串口
        {
            try
            {
                serialPort.PortName = cbPortName.Text;
                serialPort.BaudRate = Convert.ToInt32(cbBaudRate.Text);
                serialPort.DataBits = Convert.ToInt32(cbDataBits.Text);
                StopBits[] sb = { StopBits.One, StopBits.OnePointFive, StopBits.Two };
                serialPort.StopBits = sb[cbStopBits.SelectedIndex];
                Parity[] pt = { Parity.None, Parity.Odd, Parity.Even };
                serialPort.Parity = pt[cbParity.SelectedIndex];
                serialPort.Open();

                btnOpen.BackColor = Color.Pink;
                btnOpen.Text = "关闭串口";
                btnSend.Enabled = true;
                cbPortName.Enabled = false;
                cbBaudRate.Enabled = false;
                cbDataBits.Enabled = false;
                cbStopBits.Enabled = false;
                cbParity.Enabled = false;
            }
            catch
            {
                MessageBox.Show("串口打开失败", "提示");
            }
        }

        private void CloseSerialPort() //关闭串口
        {
            serialPort.Close();

            btnOpen.BackColor = SystemColors.ControlLight;
            btnOpen.Text = "打开串口";
            btnSend.Enabled = false;
            cbPortName.Enabled = true;
            cbBaudRate.Enabled = true;
            cbDataBits.Enabled = true;
            cbStopBits.Enabled = true;
            cbParity.Enabled = true;
        }

        private void cbPortName_DropDown(object sender, EventArgs e) //串口号下拉事件
        {
            string currentName = cbPortName.Text;
            string[] names = System.IO.Ports.SerialPort.GetPortNames(); //搜索可用串口号并添加到下拉列表
            cbPortName.Items.Clear();
            cbPortName.Items.AddRange(names);
            cbPortName.Text = currentName;
        }

        private void btnOpen_Click(object sender, EventArgs e) //打开串口点击事件
        {
            if (btnOpen.Text == "打开串口")
            {
                OpenSerialPort();
            }
            else if (btnOpen.Text == "关闭串口")
            {
                CloseSerialPort();
            }
        }

        private void btnSend_Click(object sender, EventArgs e) //发送点击事件
        {
            if (serialPort.IsOpen)
            {
                if (sendMode == "HEX模式")
                {
                    byte[] dataSend = HexToBytes(tbSend.Text); //HEX转字节流
                    int count = dataSend.Length;
                    serialPort.Write(dataSend, 0, count); //串口发送
                }
                else if (sendMode == "文本模式")
                {
                    byte[] dataSend = TextToBytes(tbSend.Text, sendCoding); //文本转字节流
                    int count = dataSend.Length;
                    serialPort.Write(dataSend, 0, count); //串口发送
                }
            }
        }

        private void btnClearReceive_Click(object sender, EventArgs e) //清空接收区点击事件
        {
            tbReceive.Clear();
        }

        private void btnClearSend_Click(object sender, EventArgs e) //清空发送区点击事件
        {
            tbSend.Clear();
        }

        private void cbReceiveMode_SelectedIndexChanged(object sender, EventArgs e) //接收模式选择事件
        {
            if (cbReceiveMode.Text == "HEX模式")
            {
                cbReceiveCoding.Enabled = false;
                receiveMode = "HEX模式";
            }
            else if (cbReceiveMode.Text == "文本模式")
            {
                cbReceiveCoding.Enabled = true;
                receiveMode = "文本模式";
            }

            byteBuffer.Clear();
        }

        #endregion SerialPort
        #region Delegation Defintion
        private void DisplayUI(Bitmap bmp)
        {
            pictureBox.Image = bmp;

            if (comboBox_captureMode.SelectedItem.ToString() == "Snap")
            {
                comboBox_captureMode.Enabled = true;
            }
            //更新设置参数
            int expMs;
            int gain;
            int width;
            int height;
            if (SemaphoreHolder.is_changed) { }
            m_camera.getControlValue(ASICameraDll2.ASI_CONTROL_TYPE.ASI_EXPOSURE, out expMs);
            m_camera.getControlValue(ASICameraDll2.ASI_CONTROL_TYPE.ASI_GAIN, out gain);

            width = bmp.Width;
            height = bmp.Height;
            PixelFormat format = bmp.PixelFormat;
            ASICameraDll2.ASI_IMG_TYPE img_type = m_camera.ImgType;
            string capture_config =
                "Exp Time: "
                + expMs
                + "\n"
                + "Gain: "
                + gain
                + "\n"
                + "Resolution: "
                + width
                + " * "
                + height
                + "\n"
                + "Format: "
                + Convert.ToString(format);
            capture_config_label.Text = capture_config;
            if (!spinBox_exposure.Enabled)
            {
                spinBox_exposure.Value = expMs;
            }
        }

        private void DisplayHistogram(Bitmap bmp)
        {
            pictureBox1.Image = bmp;
            string hist_string =
                "Min: "
                + Convert.ToString(m_camera.Min_hist)
                + "\n"
                + "Max: "
                + Convert.ToString(m_camera.Max_hist)
                + "\n"
                + "Mean: "
                + Convert.ToInt32(m_camera.Mean_hist)
                + "\n"
                + "Std: "
                + Convert.ToInt32(m_camera.Std_hist)
                + "\n";
            label23.Text = hist_string;
            if (search_led_best_exp.Enabled == false)
            {
                led_array.Pwm_exp[led_array.Selected_index - 1, 1] = (int)m_camera.Min_hist;
                led_array.Pwm_exp[led_array.Selected_index - 1, 2] = (int)m_camera.Max_hist;
                led_array.Pwm_exp[led_array.Selected_index - 1, 3] = (int)m_camera.Mean_hist;
                led_array.Pwm_exp[led_array.Selected_index - 1, 4] = (int)m_camera.Std_hist;
            }

            if (button_autosave_next.Enabled || button_autoexp_save.Enabled)
            {
                SemaphoreHolder.is_search_hist = true;
            }
            if (SemaphoreHolder.search_send_led_ok)
            {
                SemaphoreHolder.is_search_hist = true;
            }
        }

        private void DisplayCapture(Bitmap bmp, uint flag)
        {
            if (flag == 4)
            {
                int expMs;
                manual_current_index.Value =
                    manual_current_index.Value + Convert.ToInt32(manual_stride.Text);
                m_camera.getControlValue(ASICameraDll2.ASI_CONTROL_TYPE.ASI_EXPOSURE, out expMs);
                if (save_exp_time_button.Checked)
                {
                    m_camera.File_name =
                        manual_title.Text + expMs + "_" + manual_current_index.Value;
                }
                else
                {
                    m_camera.File_name = manual_title.Text + "_" + manual_current_index.Value;
                }

                string save_img_dir_path =
                    m_camera.SelectedFolderPath + "/" + m_camera.File_name + ".png";
                manual_file_name.Text = m_camera.File_name;

                log +=
                    "LED"
                    + Convert.ToString(led_array.Selected_index)
                    + ":"
                    + Convert.ToString(led_array.Selected_value)
                    + ": ["
                    + Convert.ToString(m_camera.Min_hist)
                    + ","
                    + Convert.ToString(m_camera.Max_hist)
                    + ","
                    + Math.Round(Convert.ToDouble(m_camera.Mean_hist))
                    + ","
                    + Math.Round(Convert.ToDouble(m_camera.Std_hist))
                    + "]\n";
                save_img(save_img_dir_path);
            }
            else if (flag == 5)
            {
                label44.Text = Convert.ToString(led_array.Selected_value);
                m_camera.File_name =
                    "LED" + led_array.Selected_index + "_" + led_array.Selected_value;
                string save_img_dir_path =
                    m_camera.SelectedFolderPath + "/" + m_camera.File_name + ".png";
                manual_file_name.Text = m_camera.File_name;
                save_img(save_img_dir_path);

                log +=
                    "LED"
                    + Convert.ToString(led_array.Selected_index)
                    + ":"
                    + Convert.ToString(led_array.Selected_value)
                    + ": ["
                    + Convert.ToString(m_camera.Min_hist)
                    + ","
                    + Convert.ToString(m_camera.Max_hist)
                    + ","
                    + Math.Round(Convert.ToDouble(m_camera.Mean_hist))
                    + ","
                    + Math.Round(Convert.ToDouble(m_camera.Std_hist))
                    + "]\n";
            }
            void save_img(string save_img_dir_path)
            {
                //bmp.Save(save_img_dir_path);
                Cv2.ImWrite(save_img_dir_path, m_camera.save_mat);
            }
        }
        #endregion
        #region Utils Function
        private int AutoExposure(int flag)
        {
            int val = -1;
            // flag = 0 表示按照平均值自动曝光
            // flag = 1 表示按照最大值自动曝光
            if (flag == 0)
            {
                /*业务层*/
                int expMs;
                m_camera.getControlValue(ASICameraDll2.ASI_CONTROL_TYPE.ASI_EXPOSURE, out expMs);
                val = expMs * 128 / Convert.ToInt32(m_camera.Mean_hist + 1);
            }
            else if (flag == 1)
            {
                val = AutoUpdate();
            }

            //SemaphoreHolderbest_exp_count++;
            return val;
        }

        // 修改后的 AutoUpdate 方法
        // 替换原来的 AutoUpdate 方法
        // 改为按照均值不大于最大值一半来自动曝光

        private int AutoUpdate()
        {
            double mean_hist = 0;
            int target_mean = 0;  // 目标均值
            int expMs;
            int val = 32;
            m_camera.getControlValue(ASICameraDll2.ASI_CONTROL_TYPE.ASI_EXPOSURE, out expMs);

            if (m_camera.ImgType == ASICameraDll2.ASI_IMG_TYPE.ASI_IMG_RAW16)
            {
                mean_hist = m_camera.Mean_hist;
                target_mean = 65535 / 10;  // RAW16最大值的一半: 32767
            }
            else  // RAW8
            {
                mean_hist = m_camera.Mean_hist;
                target_mean = 255 / 2;    // RAW8最大值的一半: 127
            }

            // 设置容差范围，避免频繁调整
            double tolerance = 0.1;  // 10%容差
            double lowerBound = target_mean * (1 - tolerance);
            double upperBound = target_mean * (1 + tolerance);

            if (mean_hist >= lowerBound && mean_hist <= upperBound)
            {
                // 均值在目标范围内，停止调整
                SemaphoreHolder.best_exp_count = 1;
                m_camera.Best_exp = expMs;
                val = m_camera.Best_exp;
            }
            else
            {
                // 按比例调整曝光时间: 新曝光 = 当前曝光 * (目标均值 / 当前均值)
                alpha = 0;
                val = (int)Math.Floor(expMs * (target_mean / (mean_hist + 1) + alpha / 255));

                // 限制曝光时间范围
                if (val < 32) val = 32;           // 最小曝光时间
                if (val > 1000000) val = 1000000; // 最大曝光时间 1s
            }

            return val;
        }


        // ============================================================
        // 如果你想要更严格地控制"均值不大于一半"，可以使用下面这个版本：
        // ============================================================

        private int AutoUpdate_StrictHalf()
        {
            double mean_hist = 0;
            int target_mean = 0;  // 目标均值（最大值的一半）
            int expMs;
            int val = 32;
            m_camera.getControlValue(ASICameraDll2.ASI_CONTROL_TYPE.ASI_EXPOSURE, out expMs);

            if (m_camera.ImgType == ASICameraDll2.ASI_IMG_TYPE.ASI_IMG_RAW16)
            {
                mean_hist = m_camera.Mean_hist;
                target_mean = 65535 / 2;  // RAW16最大值的一半: 32767
            }
            else  // RAW8
            {
                mean_hist = m_camera.Mean_hist;
                target_mean = 255 / 2;    // RAW8最大值的一半: 127
            }

            // 目标：均值不大于一半，设置目标为一半的90%，留有余量
            int safeTarget = (int)(target_mean * 0.9);

            // 设置容差范围
            double lowerBound = safeTarget * 0.85;  // 下限
            double upperBound = target_mean;         // 上限就是一半，不能超过

            if (mean_hist >= lowerBound && mean_hist <= upperBound)
            {
                // 均值在目标范围内（不大于一半），停止调整
                SemaphoreHolder.best_exp_count = 1;
                m_camera.Best_exp = expMs;
                val = m_camera.Best_exp;
            }
            else if (mean_hist > upperBound)
            {
                // 均值超过一半，需要减少曝光
                val = (int)Math.Floor(expMs * (safeTarget / (mean_hist + 1)));
            }
            else
            {
                // 均值太低，需要增加曝光
                val = (int)Math.Floor(expMs * (safeTarget / (mean_hist + 1)));
            }

            // 限制曝光时间范围
            if (val < 32) val = 32;           // 最小曝光时间
            if (val > 1000000) val = 1000000; // 最大曝光时间 1s

            return val;
        }
        private void SetCameraExposure(int val)
        {
            m_camera.setControlValue(
                ASICameraDll2.ASI_CONTROL_TYPE.ASI_EXPOSURE,
                val,
                ASICameraDll2.ASI_BOOL.ASI_FALSE
            );
        }

        private void exposureAuto()
        {
            this.Invoke(
                (EventHandler)(
                    delegate
                    {
                        trackBar_exposure.Enabled = false;
                        spinBox_exposure.Enabled = false;
                    }
                )
            );

            Thread thread = new Thread(() =>
            {
                Thread.CurrentThread.Name = "Auto Exposure";
                while (checkBox_exposureAuto.Checked)
                {
                    int val = AutoUpdate();
                    m_camera.setControlValue(
                        ASICameraDll2.ASI_CONTROL_TYPE.ASI_EXPOSURE,
                        val,
                        ASICameraDll2.ASI_BOOL.ASI_TRUE
                    );
                    //SemaphoreHolder.count++;
                    if (SemaphoreHolder.best_exp_count == 1)
                    {
                        // Invoke是同步会阻塞当前线程，begininvoke是异步
                        this.Invoke(
                            (MethodInvoker)
                                delegate
                                {
                                    SemaphoreHolder.best_exp_count = 0;
                                    checkBox_exposureAuto.Checked = false;
                                }
                        );
                        break;
                    }

                    while (!SemaphoreHolder.is_hist_updated) { }
                    SemaphoreHolder.is_hist_updated = false;
                }
            });
            thread.Start();
        }

        private void SendLEDValues()
        {
            if (serialPort.IsOpen)
            {
                SemaphoreHolder.stopwatch.Start();
                SemaphoreHolder.sw_serial.Start();
                byte[] valid_flag = { (byte)'y' };
                if (this.InvokeRequired)
                {
                    // 这样委托给主线程同时使用invoke使子线程必须等主线程write完才结束
                    // 保证了一定是先write所有再在主线程触发接收串口数据,连锁都不需要上了
                    this.BeginInvoke(
                        (MethodInvoker)
                            delegate
                            {
                                send_byte();
                            }
                    );
                }
                else
                {
                    send_byte();
                }
            }
            void send_byte()
            {
                //byte[] hexData = new byte[] { 1, 100, 2, 39, 3, 40, 0x0D }; // 将十六进制0x1转为字节数组，这里只有一个字节，如果要发多个十六进制数据依次罗列在数组中即可

                //var len = hexData.Length;
                //len = 2;
                //serialPort.Write(hexData, 0, len);
                serialPort.Write(led_array.Value, 0, led_array.Value.Length);
                //serialPort.Write("\r");
            }
        }

        private void serialPort_DataReceived(object sender, SerialDataReceivedEventArgs e) //串口接收数据事件时,开启的是子进程不是主进程!
        {
            if (serialPort.IsOpen)
            {
                int count = serialPort.BytesToRead;
                byte[] dataReceive = new byte[count];
                serialPort.Read(dataReceive, 0, count); //串口接收
                this.BeginInvoke(
                    (EventHandler)(
                        delegate
                        {
                            if (receiveMode == "HEX模式")
                            {
                                tbReceive.AppendText(BytesToHex(dataReceive)); //字节流转HEX
                            }

                            //if (dataReceive.Contains((byte)'y'))
                            if (true)
                            {
                                // 停止计时
                                SemaphoreHolder.stopwatch.Stop();
                                // 获取经过的时间
                                TimeSpan ts = SemaphoreHolder.stopwatch.Elapsed;

                                tb_beta.AppendText(Convert.ToString(ts.TotalMilliseconds) + "ms\n");
                                SemaphoreHolder.stopwatch.Reset();
                                // 只有处于auto状态才能改变标志位
                                // 测试：添加search
                                if (!single_auto_button.Enabled || !full_auto_button.Enabled)
                                {
                                    SemaphoreHolder.is_received_auto = true;
                                }
                            }
                        }
                    )
                );
            }
        }

        #endregion
        #region Click Event
        private void clear_button_Click(object sender, EventArgs e)
        {
            for (int i = 0; i < 16; i++)
            {
                ledSpinBoxs[i].Value = 0;
            }
        }

        private void open_dir_button_Click(object sender, EventArgs e)
        {
            Process.Start(m_camera.SelectedFolderPath);
        }

        private void auto_button_Click(object sender, EventArgs e)
        {
            if (sender == single_auto_button)
            {
                Thread thread = new Thread(() =>
                {
                    Thread.CurrentThread.Name = "Single Auto";
                    single_auto_button.Invoke(
                        (MethodInvoker)
                            delegate
                            {
                                single_auto_button.Enabled = false;
                                full_auto_button.Enabled = false;
                                send_button.Enabled = false;
                            }
                    );

                    int count = (int)
                        Math.Floor((double)(SemaphoreHolder.sample_count / led_array.Stride));
                    int expMs;
                    m_camera.getControlValue(
                        ASICameraDll2.ASI_CONTROL_TYPE.ASI_EXPOSURE,
                        out expMs
                    );
                    log += "Exp Time: " + expMs + "\n";
                    log += "LED" + led_array.Selected_index + "\n";
                    for (int i = 0; i < 16; i++)
                    {
                        led_array.Value[i] = 0;
                    }
                    SendLEDValues();

                    for (int i = 0; i <= count; i++)
                    {
                        led_array.Selected_value = (byte)(led_array.Stride * i);
                        led_array.Value[led_array.Selected_index - 1] = led_array.Selected_value;
                        // SendLEDValues()涉及主线程，不能阻塞
                        SendLEDValues();
                        while (!SemaphoreHolder.is_updated_auto) { }
                        SemaphoreHolder.is_updated_auto = false;
                        int value = (int)ud_timer.Value * 1000;
                        //Thread.Sleep(value);
                        // 需要等待更新hist
                        if (
                            (
                                m_camera.ImgType == ASICameraDll2.ASI_IMG_TYPE.ASI_IMG_RAW16
                                && m_camera.Max_hist >= 65500
                            )
                            || (
                                m_camera.ImgType == ASICameraDll2.ASI_IMG_TYPE.ASI_IMG_RAW8
                                && m_camera.Max_hist >= 255
                            )
                        )
                        {
                            break;
                        }
                    }

                    try
                    {
                        File.WriteAllText(
                            m_camera.SelectedFolderPath
                                + "/"
                                + "LED"
                                + led_array.Selected_index
                                + ".txt",
                            log
                        );
                        log = "";
                    }
                    catch (Exception ex)
                    {
                        Console.WriteLine("保存文件时出错: " + ex.Message);
                    }
                    this.Invoke(
                        (MethodInvoker)
                            delegate
                            {
                                single_auto_button.Enabled = true;
                                send_button.Enabled = true;
                                full_auto_button.Enabled = true;
                                selected_index_ud.Value++;
                            }
                    );
                });
                thread.Start();
            }
            else if (sender == full_auto_button)
            {
                Thread thread = new Thread(() =>
                {
                    Thread.CurrentThread.Name = "Full Auto";
                    this.Invoke(
                        (MethodInvoker)
                            delegate
                            {
                                single_auto_button.Enabled = false;
                                full_auto_button.Enabled = false;
                                send_button.Enabled = false;
                            }
                    );
                    for (int j = led_array.Selected_index - 1; j < 14; j++)
                    {
                        int count = (int)
                            Math.Floor((double)(SemaphoreHolder.sample_count / led_array.Stride));
                        int expMs;
                        m_camera.getControlValue(
                            ASICameraDll2.ASI_CONTROL_TYPE.ASI_EXPOSURE,
                            out expMs
                        );
                        log += "Exp Time: " + expMs + "\n";
                        log += "LED" + led_array.Selected_index + "\n";
                        for (int i = 0; i < 16; i++)
                        {
                            led_array.Value[i] = 0;
                        }
                        SendLEDValues();

                        for (int i = 0; i <= count; i++)
                        {
                            led_array.Selected_value = (byte)(led_array.Stride * i);
                            led_array.Value[led_array.Selected_index - 1] =
                                led_array.Selected_value;
                            // SendLEDValues()涉及主线程，不能阻塞
                            SendLEDValues();
                            while (!SemaphoreHolder.is_updated_auto) { }
                            SemaphoreHolder.is_updated_auto = false;
                            // 需要等待更新hist
                            if (
                                (
                                    m_camera.ImgType == ASICameraDll2.ASI_IMG_TYPE.ASI_IMG_RAW16
                                    && m_camera.Max_hist >= 65500
                                )
                                || (
                                    m_camera.ImgType == ASICameraDll2.ASI_IMG_TYPE.ASI_IMG_RAW8
                                    && m_camera.Max_hist >= 255
                                )
                            )
                            {
                                break;
                            }
                        }

                        led_array.Selected_index++;
                    }
                    try
                    {
                        // 直接将字符串写入文件，如果文件已存在则覆盖
                        File.WriteAllText(
                            m_camera.SelectedFolderPath + "/" + "LED_Full_Auto.txt",
                            log
                        );
                        log = "";
                    }
                    catch (Exception ex)
                    {
                        Console.WriteLine("保存文件时出错: " + ex.Message);
                    }
                    this.Invoke(
                        (MethodInvoker)
                            delegate
                            {
                                single_auto_button.Enabled = true;
                                send_button.Enabled = true;
                                full_auto_button.Enabled = true;
                                selected_index_ud.Value++;
                            }
                    );
                });
                thread.Start();
            }
        }

        private void send_button_Click(object sender, EventArgs e)
        {
            SendLEDValues();
        }

        private void pwm_exp_Click(object sender, EventArgs e)
        {
            if (sender == search_led_best_exp)
            {
                Thread thread = new Thread(() =>
                {
                    for (int i = 0; i < 16; i++)
                    {
                        led_array.Value[i] = 0;
                    }
                    SendLEDValues();
                    this.Invoke(
                        (MethodInvoker)
                            delegate
                            {
                                search_led_best_exp.Enabled = false;
                            }
                    );
                    // LED先清0

                    for (int i = 1; i < 14; i++)
                    {
                        // 设置亮度
                        led_array.Selected_index = (byte)(i + 1);
                        led_array.Selected_value = 100;
                        led_array.Value[led_array.Selected_index - 1] = led_array.Selected_value;
                        SendLEDValues();
                        // 等待主线程：更新hist完成
                        SemaphoreHolder.search_send_led_ok = true;
                        while (!SemaphoreHolder.is_search_hist) { }
                        SemaphoreHolder.is_search_hist = false;
                        // 等待主线程：自动曝光完成
                        this.Invoke(
                            (MethodInvoker)
                                delegate
                                {
                                    button_autoexp_save.Enabled = false;
                                    button_autosave_next.Enabled = false;
                                    checkBox_exposureAuto.Checked = true;
                                }
                        );
                        while (checkBox_exposureAuto.Checked) { }
                        //  等待主线程：保存图片完成
                        this.Invoke(
                            (MethodInvoker)
                                delegate
                                {
                                    SemaphoreHolder.is_manual = true;
                                }
                        );
                        while (SemaphoreHolder.is_manual) { }
                    }

                    try
                    {
                        File.WriteAllText(
                            m_camera.SelectedFolderPath + "/" + "LED_Search.txt",
                            log
                        );
                        log = "";
                    }
                    catch (Exception ex)
                    {
                        Console.WriteLine("保存文件时出错: " + ex.Message);
                    }
                    this.Invoke(
                        (MethodInvoker)
                            delegate
                            {
                                search_led_best_exp.Enabled = true;
                            }
                    );
                    // LED后清0
                    for (int i = 0; i < 16; i++)
                    {
                        led_array.Value[i] = 0;
                    }
                    SendLEDValues();
                });
                thread.Start();
            }
            // 修改后的 button_next 点击事件代码片段
            // 替换原来的 else if (sender == button_next) 代码块

            else if (sender == button_next)
            {
                // 只在这些LED索引之间切换 (0-based): LED2=1, LED4=3, LED5=4, LED6=5, LED7=6, LED8=7, LED9=8, LED10=9, LED14=13
                int[] validLedIndices = { 1,  4, 5, 6, 7, 8, 9, 13 };

                int non_zero_count = 0;
                int non_zero_index = -1;
                int non_zero_value = -1;
                // 寻找有多少非0项
                for (int i = 0; i < 16; i++)
                {
                    if (ledSpinBoxs[i].Value != 0)
                    {
                        non_zero_count++;
                        if (non_zero_count > 1)
                        {
                            break;
                        }
                        non_zero_index = i;
                        non_zero_value = (int)ledSpinBoxs[i].Value;
                    }
                }
                // 只有一个非0项的时候执行next，其余情况默认初始化led2.value
                if (non_zero_count == 1)
                {
                    ledSpinBoxs[non_zero_index].Value = 0;

                    // 在validLedIndices中找到当前索引的位置，然后切换到下一个
                    int currentPos = Array.IndexOf(validLedIndices, non_zero_index);
                    int nextIndex;
                    if (currentPos == -1 || currentPos == validLedIndices.Length - 1)
                    {
                        // 当前不在有效列表中或已是最后一个，回到第一个(LED2)
                        nextIndex = validLedIndices[0];
                    }
                    else
                    {
                        // 切换到下一个有效LED
                        nextIndex = validLedIndices[currentPos + 1];
                    }

                    ledSpinBoxs[nextIndex].Value = (byte)non_zero_value;
                    non_zero_index = nextIndex;
                }
                else
                {
                    for (int i = 0; i < 16; i++)
                    {
                        ledSpinBoxs[i].Value = 0;
                    }
                    // 默认从LED2开始 (index=1)
                    ledSpinBoxs[1].Value = 100;
                    non_zero_index = 1;
                    non_zero_value = 100;
                }
                led_array.Selected_index = (byte)(non_zero_index + 1);
                led_array.Selected_value = (byte)non_zero_value;
                SendLEDValues();
            }
        }

        private void start_mono_Click(object sender, EventArgs e)
        {
            if (sender == start_mono)
            {
                Thread thread = new Thread(() => { });
                thread.Start();
            }
        }

        private void manual_Click(object sender, EventArgs e)
        {
            if (sender == manual_restart_button)
            {
                manual_current_index.Value = manual_start_index.Value - 1;
            }
            else if (sender == manual_current_index) { }
            else if (sender == manual_save_button)
            {
                SemaphoreHolder.is_manual = true;
            }
            else if (sender == button_autoexp_save)
            {
                Thread thread = new Thread(() =>
                { // 等待主线程：自动曝光完成
                    this.Invoke(
                        (MethodInvoker)
                            delegate
                            {
                                button_autoexp_save.Enabled = false;
                                button_autosave_next.Enabled = false;
                                checkBox_exposureAuto.Checked = true;
                            }
                    );
                    while (checkBox_exposureAuto.Checked) { }
                    //等待主线程：保存图片完成
                    this.Invoke(
                        (MethodInvoker)
                            delegate
                            {
                                SemaphoreHolder.is_manual = true;
                            }
                    );
                    while (SemaphoreHolder.is_manual) { }
                    this.Invoke(
                        (MethodInvoker)
                            delegate
                            {
                                button_autoexp_save.Enabled = true;
                                button_autosave_next.Enabled = true;
                            }
                    );
                });
                thread.Start();
            }
            else if (sender == button_autosave_next)
            {
                Thread thread = new Thread(() =>
                { // 等待主线程：自动曝光完成
                    this.Invoke(
                        (MethodInvoker)
                            delegate
                            {
                                button_autoexp_save.Enabled = false;
                                button_autosave_next.Enabled = false;
                                checkBox_exposureAuto.Checked = true;
                            }
                    );
                    while (checkBox_exposureAuto.Checked) { }
                    //等待主线程：保存图片完成
                    this.Invoke(
                        (MethodInvoker)
                            delegate
                            {
                                SemaphoreHolder.is_manual = true;
                            }
                    );
                    while (SemaphoreHolder.is_manual) { }
                    this.Invoke(
                        (MethodInvoker)
                            delegate
                            {
                                button_autoexp_save.Enabled = true;
                                button_autosave_next.Enabled = true;
                                button_next.PerformClick();
                            }
                    );
                });
                thread.Start();
            }
        }

        private void mono_search_Click(object sender, EventArgs e)
        {
            if (sender == mono_search_clear1)
            {
                mono_search_text1.Clear();
            }
        }
        #endregion

        #region Changed Event
        private void checkBox_ExpAuto_CheckedChanged(object sender, EventArgs e)
        {
            if (checkBox_exposureAuto.Checked)
            {
                exposureAuto();
            }
            else
            {
                trackBar_exposure.Enabled = true;
                spinBox_exposure.Enabled = true;
            }
        }

        private void spinBox_exposure_ValueChanged(object sender, EventArgs e)
        {
            if (!spinBox_exposure.Enabled)
                return;

            int val = (int)spinBox_exposure.Value;

            m_camera.setControlValue(
                ASICameraDll2.ASI_CONTROL_TYPE.ASI_EXPOSURE,
                val,
                ASICameraDll2.ASI_BOOL.ASI_TRUE
            );
        }

        private void exp_label_Changed(object sender, EventArgs e)
        {
            this.Invoke(
                (MethodInvoker)
                    delegate
                    {
                        int expUs;
                        m_camera.getControlValue(
                            ASICameraDll2.ASI_CONTROL_TYPE.ASI_EXPOSURE,
                            out expUs
                        );
                        double expMs = expUs;
                        if (expMs >= 1000000)
                        {
                            expMs = expMs / 1000000;
                            exp_label.Text = Convert.ToString(expMs) + "s";
                        }
                        else if (expMs < 1000000 && expMs >= 1000)
                        {
                            expMs = expMs / 1000;
                            exp_label.Text = Convert.ToString(expMs) + "ms";
                        }
                        else
                        {
                            exp_label.Text = Convert.ToString(expMs) + "us";
                        }
                    }
            );
        }

        private void stride_box_SelectedIndexChanged(object sender, EventArgs e)
        {
            led_array.Stride = Convert.ToByte(stride_box.SelectedItem);
        }
        #endregion

        #endregion


        private void numericUpDown17_ValueChanged(object sender, EventArgs e)
        {
            for (int i = 0; i < 16; i++)
            {
                ledSpinBoxs[i].Increment = numericUpDown17.Value;
            }
        }

        private void count_ud_ValueChanged(object sender, EventArgs e)
        {
            SemaphoreHolder.sample_count = (int)count_ud.Value;
        }

        private void numericUpDown18_ValueChanged(object sender, EventArgs e)
        {
            led_array.Selected_index = Convert.ToByte(selected_index_ud.Value);
        }

        private void tableLayoutPanel11_Paint(object sender, PaintEventArgs e) { }

        private void ud_timer_ValueChanged(object sender, EventArgs e) { }

        private void ud_get_video_count_ValueChanged(object sender, EventArgs e)
        {
            SemaphoreHolder.get_video_count = (int)ud_get_video_count.Value;
        }

        private void ud_meter_exptime_ValueChanged(object sender, EventArgs e)
        {
            // set曝光时间
            meter.setExpTime((uint)ud_meter_exptime.Value * 1000);
        }

        private void bt_open_meter_Click(object sender, EventArgs e)
        {
            // 测试
            //meter.startTestThread();

            bt_open_meter.Enabled = false;
            bt_close_meter.Enabled = !bt_open_meter.Enabled;

            bt_save_spec.Enabled = !bt_open_meter.Enabled;
            meter.Ocean = OceanDirect.getInstance();
            int errorCode = 0; // errorCode returns as zero
            // Get meter设备数
            meter.Devices = meter.Ocean.findDevices(); // Find all attached Ocean Spectrometers

            if (meter.Devices.Length != 0) // If number of devices not equal 0
            {
                textBox2.AppendText("Found " + meter.Devices.Length + " spectrometers");
            }
            else // No spectrometers found
            {
                textBox2.AppendText("Did not find any spectrometers");
                bt_open_meter.Enabled = true;
                bt_save_spec.Enabled = !bt_open_meter.Enabled;
                // 测试
                //bt_save_spec.Enabled = bt_open_meter.Enabled;
                bt_close_meter.Enabled = !bt_open_meter.Enabled;
                return;
            }
            // Get meter的ID号
            meter.DeviceID = meter.Devices[0].Id; // For this example, assume only 1 device index = 0;
            textBox2.AppendText("DeviceID  = " + meter.DeviceID.ToString());
            // Open meter
            meter.Ocean.openDevice(meter.DeviceID, ref errorCode);
            meter.ErrorCode = errorCode;
            if (errorCode == 0) // If errorCode is still 0, the device was opened
            {
                textBox2.AppendText("Device was opened");
            }
            else
            {
                textBox2.AppendText("Device was not opened");
                bt_open_meter.Enabled = true;
                bt_save_spec.Enabled = !bt_open_meter.Enabled;
                bt_close_meter.Enabled = !bt_open_meter.Enabled;
                return; // Need to figure out why
            }
            // set曝光时间
            meter.setExpTime((uint)ud_meter_exptime.Value);
            meter.startMeterThread();
        }

        private void bt_closemeter_Click(object sender, EventArgs e)
        {
            int errorCode = 0;
            meter.Ocean.closeDevice(meter.DeviceID, ref errorCode);
            if (errorCode == 0)
            {
                textBox2.AppendText("Close Meter Success");
                bt_open_meter.Enabled = true;
                bt_save_spec.Enabled = !bt_open_meter.Enabled;
                bt_close_meter.Enabled = !bt_open_meter.Enabled;
            }
            else
            {
                textBox2.AppendText("Close Meter Failed!");
            }
        }

        private void bt_save_spec_Click(object sender, EventArgs e)
        {
            if (sender == bt_save_spec)
            {
                SemaphoreHolder.is_save_meter = true;
            }
        }

        private void bt_meter_auto_save_Click(object sender, EventArgs e)
        {
            Thread thread = new Thread(() =>
            {
                Thread.CurrentThread.Name = "Auto Exp & Auto Save";
                //single_auto_button.Invoke(
                //    (MethodInvoker)
                //        delegate
                //        {
                //            single_auto_button.Enabled = false;
                //            full_auto_button.Enabled = false;
                //            send_button.Enabled = false;
                //        }
                //);

                int count = (int)
                    Math.Floor((double)(SemaphoreHolder.sample_count / led_array.Stride));
                int expMs;
                m_camera.getControlValue(ASICameraDll2.ASI_CONTROL_TYPE.ASI_EXPOSURE, out expMs);
                for (int i = 0; i < 16; i++)
                {
                    led_array.Value[i] = 0;
                }
                SendLEDValues();

                for (int i = 0; i <= count; i++)
                {
                    led_array.Selected_value = (byte)(led_array.Stride * i);
                    led_array.Value[led_array.Selected_index - 1] = led_array.Selected_value;
                    // SendLEDValues()涉及主线程，不能阻塞
                    SendLEDValues();
                    //while (!SemaphoreHolder.is_updated_auto) { }
                    //SemaphoreHolder.is_updated_auto = false;
                    // 自动保存光谱
                    this.Invoke(
                        (MethodInvoker)
                            delegate
                            {
                                bt_save_spec.PerformClick();
                            }
                    );
                    while (SemaphoreHolder.is_save_meter) { }
                }

                this.Invoke(
                    (MethodInvoker)
                        delegate
                        {
                            ud_meter_cur_index.Value = -1;
                            single_auto_button.Enabled = true;
                            send_button.Enabled = true;
                            full_auto_button.Enabled = true;
                            selected_index_ud.Value++;
                        }
                );
            });
            thread.Start();
        }

        private void bt_mono_confirm_Click(object sender, EventArgs e)
        {
            // 直接调用ValueChanged事件处理方法
            ud_mono_wavelength_ValueChanged(ud_mono_wavelength, EventArgs.Empty);
        
        }

        private void ud_mono_wavelength_ValueChanged(object sender, EventArgs e)
        {

            // 移动到目标位置
            var wav = (double)ud_mono_wavelength.Value;
            int pos = CmeMoCtrl.Wavelength2Position(wav, correctionCoefficient / 1000.0, zeroPosition, totalSteps);
            string moveResponse = ser.MoveToWavelength(pos);
        }

        private void bt_open_monometer_Click(object sender, EventArgs e)
        {

            (ser, zeroPosition, correctionCoefficient, totalSteps) = CmeMoInit();

            // 设置速度为255
            ser.SetSpeed(255);
            Console.WriteLine($"Current Speed: {ser.QueryScanningSpeed()}"); // 查询扫描速度

        }
    }
}
