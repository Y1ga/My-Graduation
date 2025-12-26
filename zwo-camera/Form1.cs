using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Imaging;
using System.Globalization;
using System.IO;
using System.IO.Ports;
using System.Linq;
using System.Runtime.InteropServices;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading;
using System.Windows.Forms;
using System.Windows.Forms.DataVisualization.Charting;
using OpenCvSharp; //为了使用opencv
using static ZWOptical.ASISDK.ASICameraDll2;

namespace 串口助手
{
    public partial class Form1 : Form
    {
        private Thread videoThread;
        private Thread autoChangeThread3;
        private volatile bool stopVideoThread = false;
        private volatile bool stopAutoChangeThread = false;
        string receiveMode = "HEX模式";
        string receiveCoding = "GBK";
        string sendMode = "HEX模式";
        string sendCoding = "GBK";
        private ASI_CONTROL_CAPS camera_control_caps;
        private ASI_CONTROL_TYPE camera_control_type = ASI_CONTROL_TYPE.ASI_AUTO_MAX_EXP;
        private ASI_CAMERA_INFO info;
        private int width = 1936;
        private int height = 1216;
        private ASI_ERROR_CODE is_open = ASI_ERROR_CODE.ASI_ERROR_TIMEOUT;
        private ASI_EXPOSURE_STATUS exp_status;
        private int[] led_channels = new int[16];
        private String[] led_values = new String[16];
        private int[] led_values_int = new int[16];

        // 曝光阈值
        private byte thresholdValue = 128;

        private int I = 0;

        // 记录实时相片灰度值
        private double minVal,
            maxVal;
        private Scalar meanVal,
            stddev;
        private int cameraId = 0;
        private Bitmap bitmap;
        private Boolean is_auto = false;
        private Boolean auto_exp = false;

        private int i = 0;

        // 记录当前时


        private static string datetime = Convert.ToString(
            DateTime.Now.ToString("yyyy-MM-dd-HH_mm")
        );

        private static string defaultPath = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.MyDocuments),
            "Pictures"
        );

        private string selectedFolderPath = defaultPath + '\\' + datetime;

        // 记录当次拍取的照片数
        private int numOfPictures = 0;

        // 曝光时间
        private int exp_time = 10000;

        // 增益大小
        private int gain;

        // 记录标定LED序号
        private int ledImg_i = 1;

        // 记录拍照时LED的序号与强度
        private int ledIndex = 0;
        private int ledValue = 0;

        // 记录自动曝光时led的强度
        private int ledValue3 = 0;
        private IntPtr buffer;

        List<byte> byteBuffer = new List<byte>(); //接收字节缓存区

        private void Form1_Load(object sender, EventArgs e) //窗口加载事件
        {
            cbBaudRate.SelectedIndex = 1; //控件状态初始化
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
        }

        public Form1()
        {
            InitializeComponent();
            InitDIY();
        }

        public void InitDIY()
        {
            // 初始化自动LED初始Stride和Index和采样间隔
            comboBox7.Text = "1";
            comboBox8.Text = "2";
            comboBox9.Text = "100";
            // 初始化标定区comboBox
            comboBox4.Text = "2";
            comboBox5.Text = "5";
            comboBox6.Text = "1000";

            // Image previewImg = Image.FromFile("W://temp/1.jpg");
            // pictureBox1.Image = previewImg;
            pictureBox1.SizeMode = PictureBoxSizeMode.Zoom;
            // 显示默认picture

            // 设置自动曝光Stride
            comboBox3.Text = "100";
            // 设置RadioButton的事件处理程序
            radioButton1.CheckedChanged += RadioButton_CheckedChanged;
            radioButton2.CheckedChanged += RadioButton_CheckedChanged;

            // 初始状态下选择TextBox
            textBox1.Enabled = true;
            comboBox1.Enabled = false;

            // 初始化Combobox
            comboBox1.Text = "100";
            for (int i = 1000; i <= 20000; i += 1000)
            {
                comboBox1.Items.Add(i);
            }

            // 文本框显示默认保存文件夹路径
            textBox2.Text = selectedFolderPath;
            // 初始化listbox
            InitCheckBox();
            InitTextBox();
            // 初始化led_channels
            for (int j = 0; j < 16; j++)
            {
                led_channels[j] = j + 1;
            }

            //
            updatelabel12();
        }

        private void InitTextBox()
        {
            T1.KeyPress += T1_KeyPress;
            T2.KeyPress += T2_KeyPress;
            T3.KeyPress += T3_KeyPress;
            T4.KeyPress += T4_KeyPress;
            T5.KeyPress += T5_KeyPress;
            T6.KeyPress += T6_KeyPress;
            T7.KeyPress += T7_KeyPress;
            T8.KeyPress += T8_KeyPress;
            T9.KeyPress += T9_KeyPress;
            T10.KeyPress += T10_KeyPress;
            T11.KeyPress += T11_KeyPress;
            T12.KeyPress += T12_KeyPress;
            T13.KeyPress += T13_KeyPress;
            T14.KeyPress += T14_KeyPress;
            T15.KeyPress += T15_KeyPress;
            T16.KeyPress += T16_KeyPress;
            //
            T1.TextChanged += T1_TextChanged;
            T2.TextChanged += T1_TextChanged;
            T3.TextChanged += T1_TextChanged;
            T4.TextChanged += T1_TextChanged;
            T5.TextChanged += T1_TextChanged;
            T6.TextChanged += T1_TextChanged;
            T7.TextChanged += T1_TextChanged;
            T8.TextChanged += T1_TextChanged;
            T9.TextChanged += T1_TextChanged;
            T10.TextChanged += T1_TextChanged;
            T11.TextChanged += T1_TextChanged;
            T12.TextChanged += T1_TextChanged;
            T13.TextChanged += T1_TextChanged;
            T14.TextChanged += T1_TextChanged;
            T15.TextChanged += T1_TextChanged;
            T16.TextChanged += T1_TextChanged;
            // 初始化初始值
            for (int j = 0; j < 16; j++)
            {
                led_values[j] = "0";
            }
        }

        private void InitCheckBox()
        {
            LED1.CheckedChanged += LED1_CheckedChanged;
            LED2.CheckedChanged += LED1_CheckedChanged;
            LED3.CheckedChanged += LED1_CheckedChanged;
            LED4.CheckedChanged += LED1_CheckedChanged;
            LED5.CheckedChanged += LED1_CheckedChanged;
            LED6.CheckedChanged += LED1_CheckedChanged;
            LED7.CheckedChanged += LED1_CheckedChanged;
            LED8.CheckedChanged += LED1_CheckedChanged;
            LED9.CheckedChanged += LED1_CheckedChanged;
            LED10.CheckedChanged += LED1_CheckedChanged;
            LED11.CheckedChanged += LED1_CheckedChanged;
            LED12.CheckedChanged += LED1_CheckedChanged;
            LED13.CheckedChanged += LED1_CheckedChanged;
            LED14.CheckedChanged += LED1_CheckedChanged;
            LED15.CheckedChanged += LED1_CheckedChanged;
            LED16.CheckedChanged += LED1_CheckedChanged;
        }

        // 相机初始化
        private void InitializeCamera()
        {
            int num = (int)ASIOpenCamera(1);
            if (ASIGetNumOfConnectedCameras() == 0)
            {
                MessageBox.Show("没有检测到相机");
            }
            else // 打开相机
            {
                // 获取相机属性
                ASIGetCameraProperty(out info, cameraId);

                // 打开相机
                is_open = ASIOpenCamera(cameraId);
                // 初始化相机
                ASIInitCamera(cameraId);
                // 获取控制信息例如Gain或者Exposure
                camera_control_caps.ControlType = ASI_CONTROL_TYPE.ASI_EXPOSURE;
                // 获得曝光信息
                int exp_time = ASIGetControlValue(cameraId, camera_control_type);

                // 设置图像的宽度，高度(1280 * 1024)，像素合并值以及格式(RAW8)
                ASISetROIFormat(cameraId, width, height, 1, ASI_IMG_TYPE.ASI_IMG_RAW8);
                ASISetControlValue(cameraId, camera_control_type, exp_time);
                // 设置ROI的起始位置
                // ASICameraDll2.ASISetStartPos(cameraId, 0, 0);
                tbReceive.Text = Convert.ToString(is_open);
                // 设置伽马和增益
                ASISetControlValue(cameraId, ASI_CONTROL_TYPE.ASI_GAMMA, 1);
                ASISetControlValue(cameraId, ASI_CONTROL_TYPE.ASI_GAIN, 0);
                updatelabel12();
            }
        }

        private void updatelabel12()
        {
            String exp_time_str = "";
            if (exp_time < 1000)
            {
                exp_time_str = Convert.ToString(exp_time) + "μs";
            }
            else if (exp_time < 1000000 && exp_time >= 1000)
            {
                double temp = exp_time / 1000.0;
                exp_time_str = Convert.ToString(temp) + "ms";
            }
            else if (exp_time > 1000000)
            {
                double temp = exp_time / 1000000.0;
                exp_time_str = Convert.ToString(temp) + "s";
            }
            String line1 = "当前曝光: " + exp_time_str + "\n" + "\n";
            String line2 =
                "当前增益: "
                + Convert.ToString(ASIGetControlValue(cameraId, ASI_CONTROL_TYPE.ASI_GAIN))
                + "\n"
                + "\n";
            String line3 =
                "当前伽马: "
                + Convert.ToString(ASIGetControlValue(cameraId, ASI_CONTROL_TYPE.ASI_GAMMA))
                + "\n"
                + "\n";
            String line4 =
                "当前分辨率: " + Convert.ToString(width) + "*" + Convert.ToString(height) + "\n";
            label12.Text = line1 + line2 + line3 + line4;
        }

        private void updatelabel26(String index, String value)
        {
            String line1 = "LED Index: " + index + "\n" + "\n";
            String line2 = "LED Value: " + value + "\n" + "\n";
            label26.Text = line1 + line2;
        }

        private void StartVideoCameraThread()
        {
            ASIStartVideoCapture(cameraId);
            videoThread = new Thread(VideoCameraThread);
            videoThread.Start();
        }

        private void StartLEDCameraThread3()
        {
            if (!stopAutoChangeThread)
            {
                autoChangeThread3 = new Thread(AutoChangeValues3);
                autoChangeThread3.Start();
            }
        }

        private void StopVideoCameraThread()
        {
            // 停止 videoThread
            if (videoThread != null && videoThread.IsAlive)
            {
                videoThread.Abort();
                videoThread = null;
            }
        }

        // 调用视频要用多线程
        private void VideoCameraThread()
        {
            ASI_ERROR_CODE errorCode;
            if ((int)is_open != 0)
            {
                MessageBox.Show("没有打开相机");
            }
            else
            {
                errorCode = ASISetROIFormat(cameraId, width, height, 1, ASI_IMG_TYPE.ASI_IMG_RAW8);
                if (errorCode != ASI_ERROR_CODE.ASI_SUCCESS)
                {
                    return;
                }

                ASISetControlValue(cameraId, ASI_CONTROL_TYPE.ASI_EXPOSURE, exp_time);
                if (errorCode != ASI_ERROR_CODE.ASI_SUCCESS)
                {
                    return;
                }
                while (!stopVideoThread)
                {
                    ASISetControlValue(cameraId, ASI_CONTROL_TYPE.ASI_EXPOSURE, exp_time);
                    // 开始视频模式
                    int expMs = ASIGetControlValue(cameraId, ASI_CONTROL_TYPE.ASI_EXPOSURE);
                    String line1 = "当前曝光: " + Convert.ToString(expMs) + "\n" + "\n";
                    String line2 =
                        "当前增益: "
                        + Convert.ToString(ASIGetControlValue(cameraId, ASI_CONTROL_TYPE.ASI_GAIN))
                        + "\n"
                        + "\n";
                    String line3 =
                        "当前伽马: "
                        + Convert.ToString(ASIGetControlValue(cameraId, ASI_CONTROL_TYPE.ASI_GAMMA))
                        + "\n"
                        + "\n";
                    String line4 =
                        "当前分辨率: "
                        + Convert.ToString(width)
                        + "*"
                        + Convert.ToString(height)
                        + "\n";
                    expMs /= 1000;
                    int lBuffSize = width * height * 1;
                    buffer = Marshal.AllocCoTaskMem(lBuffSize);
                    // label12.Text = line1 + line2 + line3 + line4;
                    if (
                        ASIGetVideoData(cameraId, buffer, lBuffSize, expMs * 2 + 500)
                        == ASI_ERROR_CODE.ASI_SUCCESS
                    )
                    {
                        byte[] byteArray = new byte[lBuffSize];
                        Marshal.Copy(buffer, byteArray, 0, lBuffSize);
                        Marshal.FreeCoTaskMem(buffer);
                        Bitmap bmp = new Bitmap(width, height);
                        int index = 0;

                        var lockBitmap = new LockBitmap(bmp);
                        lockBitmap.LockBits();
                        for (int i = 0; i < height; i++)
                        {
                            for (int j = 0; j < width; j++)
                            {
                                lockBitmap.SetPixel(
                                    j,
                                    i,
                                    Color.FromArgb(
                                        byteArray[index],
                                        byteArray[index],
                                        byteArray[index]
                                    )
                                );
                                index++;
                            }
                        }
                        lockBitmap.UnlockBits();
                        pictureBox1.Invoke(
                            (MethodInvoker)
                                delegate
                                {
                                    pictureBox1.Image = bmp;
                                }
                        );
                        autoExp();
                        Mat imageMat = new Mat(height, width, MatType.CV_8U);
                        Cv2.MinMaxLoc(imageMat, out minVal, out maxVal);
                        Cv2.MeanStdDev(imageMat, out meanVal, out stddev);
                        UpdateChart(imageMat);
                        bitmap = OpenCvSharp.Extensions.BitmapConverter.ToBitmap(imageMat);
                        imageMat.Release();
                        // 显示像素大小
                        imginfo.Invoke(
                            (MethodInvoker)
                                delegate
                                {
                                    imginfo.Text =
                                        "最小值："
                                        + minVal
                                        + "\n \n"
                                        + "最大值："
                                        + maxVal
                                        + "\n \n"
                                        + "平均值："
                                        + Convert.ToInt16(meanVal[0]);
                                }
                        );
                    }
                    else
                    {
                        Marshal.FreeCoTaskMem(buffer);
                    }
                }
            }
        }

        private void UpdateChart(Mat src)
        {
            byte[] imageData = new byte[src.Total() * src.Channels()];
            Marshal.Copy(src.Data, imageData, 0, imageData.Length);

            int[] grayScale = new int[256];

            Mat hist = new Mat(256, 256, MatType.CV_8U);
            Cv2.CalcHist(
                new Mat[] { src },
                new int[] { 0 },
                new Mat(),
                hist,
                1,
                new int[] { 256 },
                new Rangef[] { new Rangef(0, 256) },
                uniform: true
            );
            Marshal.Copy(hist.Data, grayScale, 0, 256);

            float grayScaleMax = grayScale.Max();
            float[] grayScaleFloat = new float[256];
            if (grayScaleMax != 0)
            {
                grayScaleFloat = grayScale.Select(x => x / grayScaleMax).ToArray();
            }
            else
            {
                // 在 grayScaleMax 为零时的处理方式
                // 例如，将 grayScaleFloat 中的所有元素设置为 0 或者进行其他适当的处理
            }
            if (chart1.InvokeRequired)
            {
                chart1.Invoke(new Action<Mat>(UpdateChart), new object[] { src });
            }
            else
            {
                chart1.Series.Clear(); // Clear the existing series before adding new data
                chart1.Series.Add("grayScaleHistogram");
                chart1.ChartAreas[0].AxisX.Minimum = 0;
                chart1.ChartAreas[0].AxisX.Maximum = 255;
                chart1.ChartAreas[0].AxisX.Interval = 50;
                chart1.ChartAreas[0].AxisY.Minimum = 0;
                chart1.ChartAreas[0].AxisY.Maximum = 1;
                chart1.Series["grayScaleHistogram"].ChartType = SeriesChartType.Point;

                for (int i = 0; i < grayScale.Length; i++)
                {
                    if (grayScaleFloat[i] != 0)
                    {
                        chart1.Series["grayScaleHistogram"].Points.AddXY(i, grayScaleFloat[i]);
                    }
                }
            }
        }

        private void CaptureCamera()
        {
            ASICloseCamera(cameraId);
            StopVideoCameraThread();
            if ((int)is_open != 0)
            {
                MessageBox.Show("没有打开相机");
            }
            else
            {
                // 开始曝光
                ASIStartExposure(cameraId, ASI_BOOL.ASI_FALSE);
                while (true)
                {
                    ASIGetExpStatus(cameraId, out exp_status);
                    if (exp_status == ASI_EXPOSURE_STATUS.ASI_EXP_SUCCESS)
                    {
                        tbReceive.Text = "exp success";
                        break;
                    }
                }

                // 曝光成功，停止曝光
                ASIStopExposure(cameraId);
                IntPtr p = Marshal.AllocHGlobal(info.MaxWidth * info.MaxHeight);
                int lBuffSize = info.MaxWidth * info.MaxHeight;
                // 获取图像，存储在p指针中
                ASIGetDataAfterExp(cameraId, p, lBuffSize);
                Mat imageMat = new Mat(info.MaxWidth, info.MaxHeight, MatType.CV_8UC1, p);
                Bitmap bitmap = OpenCvSharp.Extensions.BitmapConverter.ToBitmap(imageMat);
                imageMat.Release();
                // 显示图片
                pictureBox1.BackgroundImage = bitmap;
            }
        }

        private void CaptureCamera2(String index, String value)
        {
            stopVideoThread = true;
            StopVideoCameraThread();
            createDir(selectedFolderPath);
            String selectedFolderPath_EXP = selectedFolderPath + "\\" + "EXP";
            createDir(selectedFolderPath_EXP);
            // 保存的当前图片路径名
            String dir_path =
                selectedFolderPath_EXP + "\\" + datetime + "__" + "LED" + index + "_" + value;
            label13.Text = "当前相片数：" + Convert.ToString(i++);
            bitmap.Save(dir_path + ".bmp");
            saveText3(dir_path, index, value);
            stopVideoThread = false;
            StartVideoCameraThread();
        }

        private void CaptureCamera3(String index, String value)
        {
            stopVideoThread = true;
            StopVideoCameraThread();
            createDir(selectedFolderPath);
            String selectedFolderPath_LED = selectedFolderPath + "\\" + "LED";
            createDir(selectedFolderPath_LED);
            // 保存的当前图片路径名
            String dir_path =
                selectedFolderPath_LED + "\\" + datetime + "__" + "LED" + index + "_" + value;
            // label13.Text = "当前相片数：" + Convert.ToString(i);
            bitmap.Save(dir_path + ".bmp");
            saveText3(dir_path, index, value);
            stopVideoThread = false;
            StartVideoCameraThread();
        }

        private void saveText(String dir_path)
        {
            exp_time = ASIGetControlValue(cameraId, ASI_CONTROL_TYPE.ASI_EXPOSURE);
            String line1 = "Exposure = " + exp_time + "μs\n";
            gain = ASIGetControlValue(cameraId, ASI_CONTROL_TYPE.ASI_GAIN);
            String line2 = "Gain = " + gain + "\n";
            String line3 =
                "Gamma =" + ASIGetControlValue(cameraId, ASI_CONTROL_TYPE.ASI_GAMMA) + "\n";
            String line4 = "Width =" + width + " Height=" + height + "\n";
            String fileContent = line1 + line2 + line3 + line4;
            File.WriteAllText(dir_path + ".bmp" + ".txt", fileContent);
        }

        private void saveText3(String dir_path, String index, String value)
        {
            exp_time = ASIGetControlValue(cameraId, ASI_CONTROL_TYPE.ASI_EXPOSURE);
            String line1 = "Exposure = " + exp_time + "μs\n";
            gain = ASIGetControlValue(cameraId, ASI_CONTROL_TYPE.ASI_GAIN);
            String line2 = "Gain = " + gain + "\n";
            String line3 =
                "Gamma =" + ASIGetControlValue(cameraId, ASI_CONTROL_TYPE.ASI_GAMMA) + "\n";
            String line4 = "Width =" + width + " Height=" + height + "\n";
            String line5 = "LED Index = " + index + " LED Value = " + value + "\n";
            String line6 =
                "Min =" + minVal + " Max =" + maxVal + " Mean = " + Convert.ToInt16(meanVal[0]);
            String fileContent = line1 + line2 + line3 + line4 + line5 + line6;
            File.WriteAllText(dir_path + ".bmp" + ".txt", fileContent);
        }

        private void createDir(String folderPath)
        {
            if (!Directory.Exists(folderPath))
            {
                Directory.CreateDirectory(folderPath);
            }
        }

        private void button1_Click(object sender, EventArgs e)
        {
            stopVideoThread = false;
            StartVideoCameraThread();
        }

        private void capture_Click(object sender, EventArgs e)
        {
            InitializeCamera();
        }

        private void button2_Click(object sender, EventArgs e)
        {
            CaptureCamera2(Convert.ToString(ledIndex), Convert.ToString(ledValue));
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

        protected override void DefWndProc(ref Message m) //USB拔出事件
        {
            if (m.Msg == 0x0219) //WM_DEVICECHANGE
            {
                if (m.WParam.ToInt32() == 0x8004)
                {
                    if (btnOpen.Text == "关闭串口" && serialPort.IsOpen == false)
                    {
                        CloseSerialPort(); //USB异常拔出，关闭串口
                    }
                }
            }

            base.DefWndProc(ref m);
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

        private void serialPort_DataReceived(object sender, SerialDataReceivedEventArgs e) //串口接收数据事件
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
                            else if (receiveMode == "文本模式")
                            {
                                tbReceive.AppendText(BytesToText(dataReceive, receiveCoding)); //字节流转文本
                            }
                        }
                    )
                );
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

        private void cbReceiveCoding_SelectedIndexChanged(object sender, EventArgs e) //接收编码选择事件
        {
            if (cbReceiveCoding.Text == "GBK")
            {
                receiveCoding = "GBK";
            }
            else if (cbReceiveCoding.Text == "UTF-8")
            {
                receiveCoding = "UTF-8";
            }

            byteBuffer.Clear();
        }

        private void cbSendMode_SelectedIndexChanged(object sender, EventArgs e) //发送模式选择事件
        {
            if (cbSendMode.Text == "HEX模式")
            {
                cbSendCoding.Enabled = false;
                sendMode = "HEX模式";
            }
            else if (cbSendMode.Text == "文本模式")
            {
                cbSendCoding.Enabled = true;
                sendMode = "文本模式";
            }
        }

        private void cbSendCoding_SelectedIndexChanged(object sender, EventArgs e) //发送编码选择事件
        {
            if (cbSendCoding.Text == "GBK")
            {
                sendCoding = "GBK";
            }
            else if (cbSendCoding.Text == "UTF-8")
            {
                sendCoding = "UTF-8";
            }
        }

        private void groupBox5_Enter(object sender, EventArgs e) { }

        private void tableLayoutPanel3_Paint(object sender, PaintEventArgs e) { }

        private void tbReceive_TextChanged(object sender, EventArgs e) { }

        private void label11_Click(object sender, EventArgs e) { }

        private void RadioButton_CheckedChanged(object sender, EventArgs e)
        {
            if (radioButton1.Checked)
            {
                textBox1.Enabled = true;
                comboBox1.Enabled = false;
                exp_time = Convert.ToInt32(textBox1.Text);
                updatelabel12();
            }
            else if (radioButton2.Checked)
            {
                textBox1.Enabled = false;
                comboBox1.Enabled = true;
                exp_time = Convert.ToInt32(comboBox1.Text);
                updatelabel12();
            }
        }

        private void radioButton1_CheckedChanged(object sender, EventArgs e) { }

        private void textBox1_TextChanged(object sender, EventArgs e)
        {
            exp_time = Convert.ToInt32(textBox1.Text);
            // 如果曝光值无效，按最小值32记
            exp_time = exp_time >= 32 ? exp_time : 32;
            exp_time = exp_time <= 300000000 ? exp_time : 300000000;
            // 设置图像曝光度
            if ((int)ASISetControlValue(cameraId, camera_control_type, exp_time) != 0)
            {
                MessageBox.Show("没有打开相机,设置无效");
            }

            updatelabel12();
        }

        private void comboBox1_SelectedIndexChanged(object sender, EventArgs e)
        {
            exp_time = Convert.ToInt32(comboBox1.Text);
            // 如果曝光值无效，按最小值32记
            exp_time = exp_time >= 32 ? exp_time : 32;
            exp_time = exp_time <= 300000000 ? exp_time : 300000000;
            if ((int)ASISetControlValue(cameraId, camera_control_type, exp_time) != 0)
            {
                MessageBox.Show("没有打开相机,设置无效");
            }

            // 设置图像曝光度
            ASISetControlValue(cameraId, camera_control_type, exp_time);
            updatelabel12();
        }

        private void pictureBox1_Click(object sender, EventArgs e) { }

        private void pictureBox1_Paint(object sender, EventArgs e) { }

        private void button2_Click_1(object sender, EventArgs e)
        {
            stopVideoThread = true;
            StopVideoCameraThread();
        }

        private void button3_Click(object sender, EventArgs e)
        {
            using (FolderBrowserDialog folderBrowserDialog = new FolderBrowserDialog())
            {
                if (
                    folderBrowserDialog.ShowDialog() == DialogResult.OK
                    && !string.IsNullOrWhiteSpace(folderBrowserDialog.SelectedPath)
                )
                {
                    selectedFolderPath = folderBrowserDialog.SelectedPath;
                    textBox2.Text = selectedFolderPath;
                }
            }
        }

        private void label13_Click(object sender, EventArgs e) { }

        private void button4_Click(object sender, EventArgs e)
        {
            createDir(selectedFolderPath);
            Process.Start(selectedFolderPath);
        }

        private void label14_Click(object sender, EventArgs e) { }

        private void textBox3_TextChanged(object sender, EventArgs e) { }

        private void textBox15_TextChanged(object sender, EventArgs e) { }

        private void textBox10_TextChanged(object sender, EventArgs e) { }

        private void textBox16_TextChanged(object sender, EventArgs e) { }

        private void textBox17_TextChanged(object sender, EventArgs e) { }

        private void checkedListBox1_SelectedIndexChanged(object sender, EventArgs e) { }

        private void checkedListBox1_SelectedIndexChanged_1(object sender, EventArgs e) { }

        private void listBox1_SelectedIndexChanged(object sender, EventArgs e) { }

        private void checkBox1_CheckedChanged(object sender, EventArgs e) { }

        private void textBox3_TextChanged_1(object sender, EventArgs e) { }

        private void checkBox1_CheckedChanged_1(object sender, EventArgs e) { }

        private void LED1_CheckedChanged(object sender, EventArgs e)
        {
            CheckBox selectedCheckBox = (CheckBox)sender;
            if (selectedCheckBox.Checked)
            {
                if (selectedCheckBox == LED1)
                {
                    T1.Enabled = true;
                }
                else if (selectedCheckBox == LED2)
                {
                    T2.Enabled = true;
                }
                else if (selectedCheckBox == LED3)
                {
                    T3.Enabled = true;
                }
                else if (selectedCheckBox == LED4)
                {
                    T4.Enabled = true;
                }
                else if (selectedCheckBox == LED5)
                {
                    T5.Enabled = true;
                }
                else if (selectedCheckBox == LED6)
                {
                    T6.Enabled = true;
                }
                else if (selectedCheckBox == LED7)
                {
                    T7.Enabled = true;
                }
                else if (selectedCheckBox == LED8)
                {
                    T8.Enabled = true;
                }
                else if (selectedCheckBox == LED9)
                {
                    T9.Enabled = true;
                }
                else if (selectedCheckBox == LED10)
                {
                    T10.Enabled = true;
                }
                else if (selectedCheckBox == LED11)
                {
                    T11.Enabled = true;
                }
                else if (selectedCheckBox == LED12)
                {
                    T12.Enabled = true;
                }
                else if (selectedCheckBox == LED13)
                {
                    T13.Enabled = true;
                }
                else if (selectedCheckBox == LED14)
                {
                    T14.Enabled = true;
                }
                else if (selectedCheckBox == LED15)
                {
                    T15.Enabled = true;
                }
                else if (selectedCheckBox == LED16)
                {
                    T16.Enabled = true;
                }
            }

            if (!selectedCheckBox.Checked)
            {
                if (selectedCheckBox == LED1)
                {
                    T1.Enabled = false;
                    T1.Text = "0";
                    led_values[0] = T1.Text;
                }
                else if (selectedCheckBox == LED2)
                {
                    T2.Enabled = false;
                    T2.Text = "0";
                    led_values[1] = T2.Text;
                }
                else if (selectedCheckBox == LED3)
                {
                    T3.Enabled = false;
                    T3.Text = "0";
                    led_values[2] = T3.Text;
                }
                else if (selectedCheckBox == LED4)
                {
                    T4.Enabled = false;
                    T4.Text = "0";
                    led_values[3] = T4.Text;
                }
                else if (selectedCheckBox == LED5)
                {
                    T5.Enabled = false;
                    T5.Text = "0";
                    led_values[4] = T5.Text;
                }
                else if (selectedCheckBox == LED6)
                {
                    T6.Enabled = false;
                    T6.Text = "0";
                    led_values[5] = T6.Text;
                }
                else if (selectedCheckBox == LED7)
                {
                    T7.Enabled = false;
                    T7.Text = "0";
                    led_values[6] = T7.Text;
                }
                else if (selectedCheckBox == LED8)
                {
                    T8.Enabled = false;
                    T8.Text = "0";
                    led_values[7] = T8.Text;
                }
                else if (selectedCheckBox == LED9)
                {
                    T9.Enabled = false;
                    T9.Text = "0";
                    led_values[8] = T9.Text;
                }
                else if (selectedCheckBox == LED10)
                {
                    T10.Enabled = false;
                    T10.Text = "0";
                    led_values[9] = T10.Text;
                }
                else if (selectedCheckBox == LED11)
                {
                    T11.Enabled = false;
                    T11.Text = "0";
                    led_values[10] = T11.Text;
                }
                else if (selectedCheckBox == LED12)
                {
                    T12.Enabled = false;
                    T12.Text = "0";
                    led_values[11] = T12.Text;
                }
                else if (selectedCheckBox == LED13)
                {
                    T13.Enabled = false;
                    T13.Text = "0";
                    led_values[12] = T13.Text;
                }
                else if (selectedCheckBox == LED14)
                {
                    T14.Enabled = false;
                    T14.Text = "0";
                    led_values[13] = T14.Text;
                }
                else if (selectedCheckBox == LED15)
                {
                    T15.Enabled = false;
                    T15.Text = "0";
                    led_values[14] = T15.Text;
                }
                else if (selectedCheckBox == LED16)
                {
                    T16.Enabled = false;
                    T16.Text = "0";
                    led_values[15] = T16.Text;
                }
            }
        }

        private void T1_TextChanged(object sender, EventArgs e)
        {
            if (T1.Enabled == true)
            {
                led_values[0] = T1.Text;
            }

            if (T2.Enabled == true)
            {
                led_values[1] = T2.Text;
            }

            if (T3.Enabled == true)
            {
                led_values[2] = T3.Text;
            }

            if (T4.Enabled == true)
            {
                led_values[3] = T4.Text;
            }

            if (T5.Enabled == true)
            {
                led_values[4] = T5.Text;
            }

            if (T6.Enabled == true)
            {
                led_values[5] = T6.Text;
            }

            if (T7.Enabled == true)
            {
                led_values[6] = T7.Text;
            }

            if (T8.Enabled == true)
            {
                led_values[7] = T8.Text;
            }

            if (T9.Enabled == true)
            {
                led_values[8] = T9.Text;
            }

            if (T10.Enabled == true)
            {
                led_values[9] = T10.Text;
            }

            if (T11.Enabled == true)
            {
                led_values[10] = T11.Text;
            }

            if (T12.Enabled == true)
            {
                led_values[11] = T12.Text;
            }

            if (T13.Enabled == true)
            {
                led_values[12] = T13.Text;
            }

            if (T14.Enabled == true)
            {
                led_values[13] = T14.Text;
            }

            if (T15.Enabled == true)
            {
                led_values[14] = T15.Text;
            }

            if (T16.Enabled == true)
            {
                led_values[15] = T16.Text;
            }
        }

        // 控制文本框数字
        private void T1_KeyPress(object sender, KeyPressEventArgs e)
        {
            // 检查文本框中字符的数量是否已经达到 2 个，并且按键不是控制键
            if (T1.Text.Length >= 2 && e.KeyChar != (char)Keys.Back)
            {
                e.Handled = true; // 拦截该按键，不允许输入
            }
        }

        private void T2_KeyPress(object sender, KeyPressEventArgs e)
        {
            // 检查文本框中字符的数量是否已经达到 2 个，并且按键不是控制键
            if (T2.Text.Length >= 2 && e.KeyChar != (char)Keys.Back)
            {
                e.Handled = true; // 拦截该按键，不允许输入
            }
        }

        private void T3_KeyPress(object sender, KeyPressEventArgs e)
        {
            // 检查文本框中字符的数量是否已经达到 2 个，并且按键不是控制键
            if (T3.Text.Length >= 2 && e.KeyChar != (char)Keys.Back)
            {
                e.Handled = true; // 拦截该按键，不允许输入
            }
        }

        private void T4_KeyPress(object sender, KeyPressEventArgs e)
        {
            // 检查文本框中字符的数量是否已经达到 2 个，并且按键不是控制键
            if (T4.Text.Length >= 2 && e.KeyChar != (char)Keys.Back)
            {
                e.Handled = true; // 拦截该按键，不允许输入
            }
        }

        private void T5_KeyPress(object sender, KeyPressEventArgs e)
        {
            // 检查文本框中字符的数量是否已经达到 2 个，并且按键不是控制键
            if (T5.Text.Length >= 2 && e.KeyChar != (char)Keys.Back)
            {
                e.Handled = true; // 拦截该按键，不允许输入
            }
        }

        private void T6_KeyPress(object sender, KeyPressEventArgs e)
        {
            // 检查文本框中字符的数量是否已经达到 2 个，并且按键不是控制键
            if (T6.Text.Length >= 2 && e.KeyChar != (char)Keys.Back)
            {
                e.Handled = true; // 拦截该按键，不允许输入
            }
        }

        private void T7_KeyPress(object sender, KeyPressEventArgs e)
        {
            // 检查文本框中字符的数量是否已经达到 2 个，并且按键不是控制键
            if (T7.Text.Length >= 2 && e.KeyChar != (char)Keys.Back)
            {
                e.Handled = true; // 拦截该按键，不允许输入
            }
        }

        private void T8_KeyPress(object sender, KeyPressEventArgs e)
        {
            // 检查文本框中字符的数量是否已经达到 2 个，并且按键不是控制键
            if (T8.Text.Length >= 2 && e.KeyChar != (char)Keys.Back)
            {
                e.Handled = true; // 拦截该按键，不允许输入
            }
        }

        private void T9_KeyPress(object sender, KeyPressEventArgs e)
        {
            // 检查文本框中字符的数量是否已经达到 2 个，并且按键不是控制键
            if (T9.Text.Length >= 2 && e.KeyChar != (char)Keys.Back)
            {
                e.Handled = true; // 拦截该按键，不允许输入
            }
        }

        private void T10_KeyPress(object sender, KeyPressEventArgs e)
        {
            // 检查文本框中字符的数量是否已经达到 2 个，并且按键不是控制键
            if (T10.Text.Length >= 2 && e.KeyChar != (char)Keys.Back)
            {
                e.Handled = true; // 拦截该按键，不允许输入
            }
        }

        private void T11_KeyPress(object sender, KeyPressEventArgs e)
        {
            // 检查文本框中字符的数量是否已经达到 2 个，并且按键不是控制键
            if (T11.Text.Length >= 2 && e.KeyChar != (char)Keys.Back)
            {
                e.Handled = true; // 拦截该按键，不允许输入
            }
        }

        private void T12_KeyPress(object sender, KeyPressEventArgs e)
        {
            // 检查文本框中字符的数量是否已经达到 2 个，并且按键不是控制键
            if (T12.Text.Length >= 2 && e.KeyChar != (char)Keys.Back)
            {
                e.Handled = true; // 拦截该按键，不允许输入
            }
        }

        private void T13_KeyPress(object sender, KeyPressEventArgs e)
        {
            // 检查文本框中字符的数量是否已经达到 2 个，并且按键不是控制键
            if (T13.Text.Length >= 2 && e.KeyChar != (char)Keys.Back)
            {
                e.Handled = true; // 拦截该按键，不允许输入
            }
        }

        private void T14_KeyPress(object sender, KeyPressEventArgs e)
        {
            // 检查文本框中字符的数量是否已经达到 2 个，并且按键不是控制键
            if (T14.Text.Length >= 2 && e.KeyChar != (char)Keys.Back)
            {
                e.Handled = true; // 拦截该按键，不允许输入
            }
        }

        private void T15_KeyPress(object sender, KeyPressEventArgs e)
        {
            // 检查文本框中字符的数量是否已经达到 2 个，并且按键不是控制键
            if (T15.Text.Length >= 2 && e.KeyChar != (char)Keys.Back)
            {
                e.Handled = true; // 拦截该按键，不允许输入
            }
        }

        private void T16_KeyPress(object sender, KeyPressEventArgs e)
        {
            // 检查文本框中字符的数量是否已经达到 2 个，并且按键不是控制键
            if (T16.Text.Length >= 2 && e.KeyChar != (char)Keys.Back)
            {
                e.Handled = true; // 拦截该按键，不允许输入
            }
        }

        private void button5_Click(object sender, EventArgs e)
        {
            writeValues();
            // autoChangeValues();
        }

        private void writeValues()
        {
            if (serialPort.IsOpen)
            {
                byte[] temp = BitConverter.GetBytes(0);
                // serialPort.Write(temp, 0, 1);
                for (int j = 0; j < 16; j++)
                {
                    led_values_int[j] = Convert.ToInt32(led_values[j]);
                    byte[] channel = BitConverter.GetBytes(led_channels[j]);
                    byte[] values = BitConverter.GetBytes(led_values_int[j]);
                    // 先发送信号
                    serialPort.Write(channel, 0, 1);
                    serialPort.Write(values, 0, 1);
                }

                int temp2 = 0;
            }
        }

        private void label12_Click(object sender, EventArgs e) { }

        private void hScrollBar1_Scroll(object sender, ScrollEventArgs e)
        {
            updatelabel12();
        }

        private void tableLayoutPanel1_Paint(object sender, PaintEventArgs e) { }

        private void imginfo_Click(object sender, EventArgs e)
        {
            throw new System.NotImplementedException();
        }

        private void checkBox1_CheckedChanged_2(object sender, EventArgs e)
        {
            if (checkBox1.Checked)
            {
                is_auto = true;
                StartLEDCameraThread3();
            }
            else
            {
                is_auto = false;
            }
        }

        private void autoChangeValues()
        {
            if (is_auto)
            {
                int autoLEDStride = Convert.ToInt32(comboBox7.Text);
                if (stopVideoThread == false)
                // if (stopVideoThread == false)
                {
                    // 均值小于等于100就持续曝光
                    Thread.Sleep(50);
                    for (int j = 0; j < led_values.Length; j++)
                    {
                        led_values_int[j] = Convert.ToInt16(led_values[j]);
                        if (led_values_int[j] != 0)
                        {
                            if (
                                meanVal[0] <= thresholdValue
                                && led_values_int[j] <= 100
                                && maxVal < 255
                            )
                            {
                                led_values_int[j] += autoLEDStride;
                            }
                            else if (meanVal[0] > thresholdValue || maxVal >= 255)
                            {
                                led_values_int[j] -= autoLEDStride;
                            }
                            led_values[j] = Convert.ToString(led_values_int[j]);
                            writeValues();
                        }
                    }
                }
            }
        }

        private void AutoChangeValues3()
        {
            if (!stopAutoChangeThread)
            {
                int autoLEDStride = 0;
                int index = 0;
                byte[] channel = new byte[4];
                byte[] values = new byte[4];
                ledValue3 = 0;
                while (is_auto)
                {
                    comboBox7.Invoke(
                        (MethodInvoker)
                            delegate
                            {
                                autoLEDStride = Convert.ToInt32(comboBox7.Text);
                                index = Convert.ToInt32(comboBox8.Text);
                            }
                    );

                    if (stopVideoThread == false)
                    // if (stopVideoThread == false)
                    {
                        if (ledValue3 <= 100 && maxVal < 255)
                        {
                            ledValue3 += autoLEDStride;
                        }
                        else if (maxVal >= 255)
                        {
                            ledValue3 -= autoLEDStride;
                        }
                        if (ledValue3 < 0)
                        {
                            ledValue3 = 0;
                        }
                        else if (ledValue3 >= 100)
                        {
                            ledValue3 = 100;
                        }
                        channel = BitConverter.GetBytes(index);
                        values = BitConverter.GetBytes(ledValue3);
                        serialPort.Write(channel, 0, 1);
                        serialPort.Write(values, 0, 1);
                        ledIndex = channel[0];
                        ledValue = values[0];
                        updatelabel26(Convert.ToString(channel[0]), Convert.ToString(values[0]));
                        // 均值小于等于100就持续曝光
                        Thread.Sleep(Convert.ToInt32(comboBox9.Text));
                    }
                }
                // values[0] = 0;
                // serialPort.Write(channel, 0, 1);
                // serialPort.Write(values, 0, 1);
            }
        }

        private void autoExp()
        {
            int expStride = 0;
            int index = 0;
            comboBox4.Invoke(
                (MethodInvoker)
                    delegate
                    {
                        index = Convert.ToInt32(comboBox4.Text);
                        expStride = Convert.ToInt32(comboBox3.Text);
                    }
            );
            if (auto_exp)
            {
                // Thread.Sleep(10);
                if (stopVideoThread == false)
                {
                    // 均值小于等于100就持续曝光
                    if (Convert.ToInt16(meanVal[0]) <= thresholdValue)
                    {
                        exp_time += expStride;
                        ASISetControlValue(cameraId, ASI_CONTROL_TYPE.ASI_EXPOSURE, exp_time);
                        updatelabel12();
                    }
                    else
                    {
                        exp_time -= expStride;
                        ASISetControlValue(cameraId, ASI_CONTROL_TYPE.ASI_EXPOSURE, exp_time);
                        updatelabel12();
                    }
                }
            }
        }

        private void thread01()
        {
            int i = 1;
        }

        private void checkBox2_CheckedChanged(object sender, EventArgs e)
        {
            if (checkBox2.Checked)
            {
                auto_exp = true;
            }
            else
            {
                auto_exp = false;
            }
        }

        private void comboBox2_SelectedIndexChanged(object sender, EventArgs e)
        {
            string s = comboBox2.Text;
            string[] parts = s.Split('*');
            changeWH(Convert.ToInt32(parts[0]), Convert.ToInt32(parts[1]));
        }

        private void changeWH(int w, int h)
        {
            if (w % 8 == 0 && w <= 1608 && w > 0)
            {
                width = w;
            }
            else
            {
                width = 320;
            }
            if (h % 2 == 0 && h <= 1104 && h > 0)
            {
                height = h;
            }
            else
            {
                height = 240;
            }
            ASIStopVideoCapture(cameraId);
            StopVideoCameraThread();
            StartVideoCameraThread();
        }

        private void button7_Click(object sender, EventArgs e)
        {
            if (checkBox3.Checked)
            {
                int w = 0;
                int h = 0;
                if (int.TryParse(textBox4.Text, out _))
                {
                    w = Convert.ToInt32(textBox4.Text);
                }
                if (int.TryParse(textBox5.Text, out _))
                {
                    h = Convert.ToInt32(textBox5.Text);
                }
                changeWH(w, h);
            }
        }

        private void button8_Click(object sender, EventArgs e)
        {
            if (int.TryParse(comboBox4.Text, out _) && int.TryParse(comboBox5.Text, out _))
            {
                Thread ledThread = new Thread(LEDThread);
                ledThread.Start();
            }
        }

        private void LEDThread()
        {
            int index = 0;
            int valueStride = 0;
            int value = 1;
            // if (serialPort.IsOpen && !stopVideoThread)
            comboBox4.Invoke(
                (MethodInvoker)
                    delegate
                    {
                        index = Convert.ToInt32(comboBox4.Text);
                    }
            );
            comboBox5.Invoke(
                (MethodInvoker)
                    delegate
                    {
                        valueStride = Convert.ToInt32(comboBox5.Text);
                    }
            );
            byte[] channel = new byte[4];
            byte[] values = new byte[4];
            while (value <= 100)
            {
                channel = BitConverter.GetBytes(index);
                values = BitConverter.GetBytes(value);
                if (value < 0)
                {
                    value = 0;
                }
                else if (value >= 100)
                {
                    value = 100;
                    break;
                }
                else if (value < 5)
                {
                    value += 1;
                }
                else
                {
                    value += valueStride;
                }

                serialPort.Write(channel, 0, 1);
                serialPort.Write(values, 0, 1);
                if (checkBox4.Checked)
                {
                    CaptureCamera3(comboBox4.Text, Convert.ToString(value));
                }

                Thread.Sleep(Convert.ToInt32(comboBox6.Text));

                if (maxVal >= 255)
                {
                    break;
                }
            }

            values[0] = 0;
            serialPort.Write(channel, 0, 1);
            serialPort.Write(values, 0, 1);
        }

        private void button10_Click(object sender, EventArgs e)
        {
            if (autoChangeThread3 != null && autoChangeThread3.IsAlive)
            {
                autoChangeThread3.Abort();
                autoChangeThread3 = null;
            }
        }
    }

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
                _bitmapData = _source.LockBits(rect, ImageLockMode.ReadWrite, _source.PixelFormat);

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
}
