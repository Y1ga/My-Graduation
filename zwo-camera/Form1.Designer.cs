using System.Drawing;

namespace 串口助手
{
    partial class Form1
    {
        /// <summary>
        /// 必需的设计器变量。
        /// </summary>
        private System.ComponentModel.IContainer components = null;

        /// <summary>
        /// 清理所有正在使用的资源。
        /// </summary>
        /// <param name="disposing">如果应释放托管资源，为 true；否则为 false。</param>
        protected override void Dispose(bool disposing)
        {
            if (disposing && (components != null))
            {
                components.Dispose();
            }
            base.Dispose(disposing);
        }

        #region Windows 窗体设计器生成的代码

        /// <summary>
        /// Required method for Designer support - do not modify
        /// the contents of this method with the code editor.
        /// </summary>
        private void InitializeComponent()
        {
            this.components = new System.ComponentModel.Container();
            System.Windows.Forms.DataVisualization.Charting.ChartArea chartArea1 = new System.Windows.Forms.DataVisualization.Charting.ChartArea();
            System.Windows.Forms.DataVisualization.Charting.Legend legend1 = new System.Windows.Forms.DataVisualization.Charting.Legend();
            System.Windows.Forms.DataVisualization.Charting.Series series1 = new System.Windows.Forms.DataVisualization.Charting.Series();
            System.ComponentModel.ComponentResourceManager resources = new System.ComponentModel.ComponentResourceManager(typeof(Form1));
            this.tableLayoutPanel1 = new System.Windows.Forms.TableLayoutPanel();
            this.tableLayoutPanel3 = new System.Windows.Forms.TableLayoutPanel();
            this.groupBox2 = new System.Windows.Forms.GroupBox();
            this.tableLayoutPanel5 = new System.Windows.Forms.TableLayoutPanel();
            this.tbReceive = new System.Windows.Forms.TextBox();
            this.flowLayoutPanel1 = new System.Windows.Forms.FlowLayoutPanel();
            this.btnClearReceive = new System.Windows.Forms.Button();
            this.groupBox3 = new System.Windows.Forms.GroupBox();
            this.tableLayoutPanel6 = new System.Windows.Forms.TableLayoutPanel();
            this.tbSend = new System.Windows.Forms.TextBox();
            this.flowLayoutPanel2 = new System.Windows.Forms.FlowLayoutPanel();
            this.btnClearSend = new System.Windows.Forms.Button();
            this.btnSend = new System.Windows.Forms.Button();
            this.tableLayoutPanel2 = new System.Windows.Forms.TableLayoutPanel();
            this.groupBox1 = new System.Windows.Forms.GroupBox();
            this.tableLayoutPanel4 = new System.Windows.Forms.TableLayoutPanel();
            this.label3 = new System.Windows.Forms.Label();
            this.cbPortName = new System.Windows.Forms.ComboBox();
            this.label4 = new System.Windows.Forms.Label();
            this.label5 = new System.Windows.Forms.Label();
            this.label6 = new System.Windows.Forms.Label();
            this.label7 = new System.Windows.Forms.Label();
            this.label8 = new System.Windows.Forms.Label();
            this.cbBaudRate = new System.Windows.Forms.ComboBox();
            this.cbDataBits = new System.Windows.Forms.ComboBox();
            this.cbStopBits = new System.Windows.Forms.ComboBox();
            this.cbParity = new System.Windows.Forms.ComboBox();
            this.btnOpen = new System.Windows.Forms.Button();
            this.groupBox4 = new System.Windows.Forms.GroupBox();
            this.tableLayoutPanel7 = new System.Windows.Forms.TableLayoutPanel();
            this.label1 = new System.Windows.Forms.Label();
            this.cbReceiveMode = new System.Windows.Forms.ComboBox();
            this.label2 = new System.Windows.Forms.Label();
            this.cbReceiveCoding = new System.Windows.Forms.ComboBox();
            this.groupBox5 = new System.Windows.Forms.GroupBox();
            this.tableLayoutPanel8 = new System.Windows.Forms.TableLayoutPanel();
            this.label9 = new System.Windows.Forms.Label();
            this.cbSendMode = new System.Windows.Forms.ComboBox();
            this.label10 = new System.Windows.Forms.Label();
            this.cbSendCoding = new System.Windows.Forms.ComboBox();
            this.serialPort = new System.IO.Ports.SerialPort(this.components);
            this.pictureBox1 = new System.Windows.Forms.PictureBox();
            this.opencamera = new System.Windows.Forms.Button();
            this.capture = new System.Windows.Forms.Button();
            this.comboBox1 = new System.Windows.Forms.ComboBox();
            this.label11 = new System.Windows.Forms.Label();
            this.textBox1 = new System.Windows.Forms.TextBox();
            this.radioButton1 = new System.Windows.Forms.RadioButton();
            this.radioButton2 = new System.Windows.Forms.RadioButton();
            this.label12 = new System.Windows.Forms.Label();
            this.button1 = new System.Windows.Forms.Button();
            this.button2 = new System.Windows.Forms.Button();
            this.textBox2 = new System.Windows.Forms.TextBox();
            this.button3 = new System.Windows.Forms.Button();
            this.label13 = new System.Windows.Forms.Label();
            this.button4 = new System.Windows.Forms.Button();
            this.LED1 = new System.Windows.Forms.CheckBox();
            this.T1 = new System.Windows.Forms.TextBox();
            this.T2 = new System.Windows.Forms.TextBox();
            this.LED2 = new System.Windows.Forms.CheckBox();
            this.T4 = new System.Windows.Forms.TextBox();
            this.LED4 = new System.Windows.Forms.CheckBox();
            this.T3 = new System.Windows.Forms.TextBox();
            this.LED3 = new System.Windows.Forms.CheckBox();
            this.T8 = new System.Windows.Forms.TextBox();
            this.LED8 = new System.Windows.Forms.CheckBox();
            this.T7 = new System.Windows.Forms.TextBox();
            this.LED7 = new System.Windows.Forms.CheckBox();
            this.T6 = new System.Windows.Forms.TextBox();
            this.LED6 = new System.Windows.Forms.CheckBox();
            this.T5 = new System.Windows.Forms.TextBox();
            this.LED5 = new System.Windows.Forms.CheckBox();
            this.T16 = new System.Windows.Forms.TextBox();
            this.LED16 = new System.Windows.Forms.CheckBox();
            this.T15 = new System.Windows.Forms.TextBox();
            this.LED15 = new System.Windows.Forms.CheckBox();
            this.T14 = new System.Windows.Forms.TextBox();
            this.LED14 = new System.Windows.Forms.CheckBox();
            this.T13 = new System.Windows.Forms.TextBox();
            this.LED13 = new System.Windows.Forms.CheckBox();
            this.T12 = new System.Windows.Forms.TextBox();
            this.LED12 = new System.Windows.Forms.CheckBox();
            this.T11 = new System.Windows.Forms.TextBox();
            this.LED11 = new System.Windows.Forms.CheckBox();
            this.T10 = new System.Windows.Forms.TextBox();
            this.LED10 = new System.Windows.Forms.CheckBox();
            this.T9 = new System.Windows.Forms.TextBox();
            this.LED9 = new System.Windows.Forms.CheckBox();
            this.button5 = new System.Windows.Forms.Button();
            this.tableLayoutPanel9 = new System.Windows.Forms.TableLayoutPanel();
            this.tableLayoutPanel10 = new System.Windows.Forms.TableLayoutPanel();
            this.tableLayoutPanel11 = new System.Windows.Forms.TableLayoutPanel();
            this.tableLayoutPanel12 = new System.Windows.Forms.TableLayoutPanel();
            this.imginfo = new System.Windows.Forms.Label();
            this.chart1 = new System.Windows.Forms.DataVisualization.Charting.Chart();
            this.checkBox2 = new System.Windows.Forms.CheckBox();
            this.checkBox1 = new System.Windows.Forms.CheckBox();
            this.tableLayoutPanel13 = new System.Windows.Forms.TableLayoutPanel();
            this.button6 = new System.Windows.Forms.Button();
            this.textBox3 = new System.Windows.Forms.TextBox();
            this.label14 = new System.Windows.Forms.Label();
            this.comboBox2 = new System.Windows.Forms.ComboBox();
            this.textBox4 = new System.Windows.Forms.TextBox();
            this.textBox5 = new System.Windows.Forms.TextBox();
            this.label15 = new System.Windows.Forms.Label();
            this.label16 = new System.Windows.Forms.Label();
            this.label17 = new System.Windows.Forms.Label();
            this.button7 = new System.Windows.Forms.Button();
            this.checkBox3 = new System.Windows.Forms.CheckBox();
            this.comboBox3 = new System.Windows.Forms.ComboBox();
            this.label18 = new System.Windows.Forms.Label();
            this.checkBox4 = new System.Windows.Forms.CheckBox();
            this.label19 = new System.Windows.Forms.Label();
            this.comboBox4 = new System.Windows.Forms.ComboBox();
            this.button8 = new System.Windows.Forms.Button();
            this.comboBox5 = new System.Windows.Forms.ComboBox();
            this.label20 = new System.Windows.Forms.Label();
            this.label21 = new System.Windows.Forms.Label();
            this.comboBox6 = new System.Windows.Forms.ComboBox();
            this.label22 = new System.Windows.Forms.Label();
            this.label23 = new System.Windows.Forms.Label();
            this.comboBox7 = new System.Windows.Forms.ComboBox();
            this.comboBox8 = new System.Windows.Forms.ComboBox();
            this.label24 = new System.Windows.Forms.Label();
            this.button9 = new System.Windows.Forms.Button();
            this.label25 = new System.Windows.Forms.Label();
            this.comboBox9 = new System.Windows.Forms.ComboBox();
            this.label26 = new System.Windows.Forms.Label();
            this.button10 = new System.Windows.Forms.Button();
            this.tableLayoutPanel1.SuspendLayout();
            this.tableLayoutPanel3.SuspendLayout();
            this.groupBox2.SuspendLayout();
            this.tableLayoutPanel5.SuspendLayout();
            this.flowLayoutPanel1.SuspendLayout();
            this.groupBox3.SuspendLayout();
            this.tableLayoutPanel6.SuspendLayout();
            this.flowLayoutPanel2.SuspendLayout();
            this.tableLayoutPanel2.SuspendLayout();
            this.groupBox1.SuspendLayout();
            this.tableLayoutPanel4.SuspendLayout();
            this.groupBox4.SuspendLayout();
            this.tableLayoutPanel7.SuspendLayout();
            this.groupBox5.SuspendLayout();
            this.tableLayoutPanel8.SuspendLayout();
            ((System.ComponentModel.ISupportInitialize)(this.pictureBox1)).BeginInit();
            this.tableLayoutPanel9.SuspendLayout();
            this.tableLayoutPanel10.SuspendLayout();
            this.tableLayoutPanel11.SuspendLayout();
            this.tableLayoutPanel12.SuspendLayout();
            ((System.ComponentModel.ISupportInitialize)(this.chart1)).BeginInit();
            this.tableLayoutPanel13.SuspendLayout();
            this.SuspendLayout();
            // 
            // tableLayoutPanel1
            // 
            this.tableLayoutPanel1.ColumnCount = 2;
            this.tableLayoutPanel1.ColumnStyles.Add(new System.Windows.Forms.ColumnStyle(System.Windows.Forms.SizeType.Percent, 100F));
            this.tableLayoutPanel1.ColumnStyles.Add(new System.Windows.Forms.ColumnStyle(System.Windows.Forms.SizeType.Absolute, 200F));
            this.tableLayoutPanel1.Controls.Add(this.tableLayoutPanel3, 0, 0);
            this.tableLayoutPanel1.Controls.Add(this.tableLayoutPanel2, 1, 0);
            this.tableLayoutPanel1.Location = new System.Drawing.Point(12, 30);
            this.tableLayoutPanel1.Name = "tableLayoutPanel1";
            this.tableLayoutPanel1.RowCount = 1;
            this.tableLayoutPanel1.RowStyles.Add(new System.Windows.Forms.RowStyle(System.Windows.Forms.SizeType.Percent, 100F));
            this.tableLayoutPanel1.Size = new System.Drawing.Size(385, 212);
            this.tableLayoutPanel1.TabIndex = 0;
            this.tableLayoutPanel1.Paint += new System.Windows.Forms.PaintEventHandler(this.tableLayoutPanel1_Paint);
            // 
            // tableLayoutPanel3
            // 
            this.tableLayoutPanel3.ColumnCount = 1;
            this.tableLayoutPanel3.ColumnStyles.Add(new System.Windows.Forms.ColumnStyle(System.Windows.Forms.SizeType.Percent, 100F));
            this.tableLayoutPanel3.Controls.Add(this.groupBox2, 0, 0);
            this.tableLayoutPanel3.Controls.Add(this.groupBox3, 0, 1);
            this.tableLayoutPanel3.Dock = System.Windows.Forms.DockStyle.Fill;
            this.tableLayoutPanel3.Location = new System.Drawing.Point(3, 3);
            this.tableLayoutPanel3.Name = "tableLayoutPanel3";
            this.tableLayoutPanel3.RowCount = 2;
            this.tableLayoutPanel3.RowStyles.Add(new System.Windows.Forms.RowStyle(System.Windows.Forms.SizeType.Percent, 100F));
            this.tableLayoutPanel3.RowStyles.Add(new System.Windows.Forms.RowStyle(System.Windows.Forms.SizeType.Absolute, 97F));
            this.tableLayoutPanel3.Size = new System.Drawing.Size(179, 206);
            this.tableLayoutPanel3.TabIndex = 1;
            this.tableLayoutPanel3.Paint += new System.Windows.Forms.PaintEventHandler(this.tableLayoutPanel3_Paint);
            // 
            // groupBox2
            // 
            this.groupBox2.Controls.Add(this.tableLayoutPanel5);
            this.groupBox2.Dock = System.Windows.Forms.DockStyle.Fill;
            this.groupBox2.Location = new System.Drawing.Point(3, 3);
            this.groupBox2.Name = "groupBox2";
            this.groupBox2.Size = new System.Drawing.Size(173, 103);
            this.groupBox2.TabIndex = 4;
            this.groupBox2.TabStop = false;
            this.groupBox2.Text = "接收区";
            // 
            // tableLayoutPanel5
            // 
            this.tableLayoutPanel5.ColumnCount = 1;
            this.tableLayoutPanel5.ColumnStyles.Add(new System.Windows.Forms.ColumnStyle(System.Windows.Forms.SizeType.Percent, 100F));
            this.tableLayoutPanel5.Controls.Add(this.tbReceive, 0, 0);
            this.tableLayoutPanel5.Controls.Add(this.flowLayoutPanel1, 0, 1);
            this.tableLayoutPanel5.Dock = System.Windows.Forms.DockStyle.Fill;
            this.tableLayoutPanel5.Location = new System.Drawing.Point(3, 17);
            this.tableLayoutPanel5.Name = "tableLayoutPanel5";
            this.tableLayoutPanel5.RowCount = 2;
            this.tableLayoutPanel5.RowStyles.Add(new System.Windows.Forms.RowStyle(System.Windows.Forms.SizeType.Percent, 100F));
            this.tableLayoutPanel5.RowStyles.Add(new System.Windows.Forms.RowStyle());
            this.tableLayoutPanel5.Size = new System.Drawing.Size(167, 83);
            this.tableLayoutPanel5.TabIndex = 0;
            // 
            // tbReceive
            // 
            this.tbReceive.Dock = System.Windows.Forms.DockStyle.Fill;
            this.tbReceive.Font = new System.Drawing.Font("宋体", 9.75F, System.Drawing.FontStyle.Regular, System.Drawing.GraphicsUnit.Point, ((byte)(134)));
            this.tbReceive.Location = new System.Drawing.Point(3, 3);
            this.tbReceive.Multiline = true;
            this.tbReceive.Name = "tbReceive";
            this.tbReceive.ScrollBars = System.Windows.Forms.ScrollBars.Vertical;
            this.tbReceive.Size = new System.Drawing.Size(161, 48);
            this.tbReceive.TabIndex = 3;
            this.tbReceive.TextChanged += new System.EventHandler(this.tbReceive_TextChanged);
            // 
            // flowLayoutPanel1
            // 
            this.flowLayoutPanel1.Anchor = System.Windows.Forms.AnchorStyles.Right;
            this.flowLayoutPanel1.AutoSize = true;
            this.flowLayoutPanel1.Controls.Add(this.btnClearReceive);
            this.flowLayoutPanel1.FlowDirection = System.Windows.Forms.FlowDirection.RightToLeft;
            this.flowLayoutPanel1.Location = new System.Drawing.Point(86, 54);
            this.flowLayoutPanel1.Margin = new System.Windows.Forms.Padding(0);
            this.flowLayoutPanel1.Name = "flowLayoutPanel1";
            this.flowLayoutPanel1.Size = new System.Drawing.Size(81, 29);
            this.flowLayoutPanel1.TabIndex = 4;
            // 
            // btnClearReceive
            // 
            this.btnClearReceive.Location = new System.Drawing.Point(3, 3);
            this.btnClearReceive.Name = "btnClearReceive";
            this.btnClearReceive.Size = new System.Drawing.Size(75, 23);
            this.btnClearReceive.TabIndex = 0;
            this.btnClearReceive.Text = "清空接收区";
            this.btnClearReceive.UseVisualStyleBackColor = true;
            this.btnClearReceive.Click += new System.EventHandler(this.btnClearReceive_Click);
            // 
            // groupBox3
            // 
            this.groupBox3.Controls.Add(this.tableLayoutPanel6);
            this.groupBox3.Dock = System.Windows.Forms.DockStyle.Fill;
            this.groupBox3.Location = new System.Drawing.Point(3, 112);
            this.groupBox3.Name = "groupBox3";
            this.groupBox3.Size = new System.Drawing.Size(173, 91);
            this.groupBox3.TabIndex = 5;
            this.groupBox3.TabStop = false;
            this.groupBox3.Text = "发送区";
            // 
            // tableLayoutPanel6
            // 
            this.tableLayoutPanel6.ColumnCount = 1;
            this.tableLayoutPanel6.ColumnStyles.Add(new System.Windows.Forms.ColumnStyle(System.Windows.Forms.SizeType.Percent, 100F));
            this.tableLayoutPanel6.Controls.Add(this.tbSend, 0, 0);
            this.tableLayoutPanel6.Controls.Add(this.flowLayoutPanel2, 0, 1);
            this.tableLayoutPanel6.Dock = System.Windows.Forms.DockStyle.Fill;
            this.tableLayoutPanel6.Location = new System.Drawing.Point(3, 17);
            this.tableLayoutPanel6.Name = "tableLayoutPanel6";
            this.tableLayoutPanel6.RowCount = 2;
            this.tableLayoutPanel6.RowStyles.Add(new System.Windows.Forms.RowStyle(System.Windows.Forms.SizeType.Percent, 100F));
            this.tableLayoutPanel6.RowStyles.Add(new System.Windows.Forms.RowStyle());
            this.tableLayoutPanel6.Size = new System.Drawing.Size(167, 71);
            this.tableLayoutPanel6.TabIndex = 0;
            // 
            // tbSend
            // 
            this.tbSend.Dock = System.Windows.Forms.DockStyle.Fill;
            this.tbSend.Font = new System.Drawing.Font("宋体", 9.75F, System.Drawing.FontStyle.Regular, System.Drawing.GraphicsUnit.Point, ((byte)(134)));
            this.tbSend.Location = new System.Drawing.Point(3, 3);
            this.tbSend.Multiline = true;
            this.tbSend.Name = "tbSend";
            this.tbSend.ScrollBars = System.Windows.Forms.ScrollBars.Vertical;
            this.tbSend.Size = new System.Drawing.Size(161, 36);
            this.tbSend.TabIndex = 5;
            // 
            // flowLayoutPanel2
            // 
            this.flowLayoutPanel2.Anchor = System.Windows.Forms.AnchorStyles.Right;
            this.flowLayoutPanel2.AutoSize = true;
            this.flowLayoutPanel2.Controls.Add(this.btnClearSend);
            this.flowLayoutPanel2.Controls.Add(this.btnSend);
            this.flowLayoutPanel2.FlowDirection = System.Windows.Forms.FlowDirection.RightToLeft;
            this.flowLayoutPanel2.Location = new System.Drawing.Point(5, 42);
            this.flowLayoutPanel2.Margin = new System.Windows.Forms.Padding(0);
            this.flowLayoutPanel2.Name = "flowLayoutPanel2";
            this.flowLayoutPanel2.Size = new System.Drawing.Size(162, 29);
            this.flowLayoutPanel2.TabIndex = 6;
            // 
            // btnClearSend
            // 
            this.btnClearSend.Location = new System.Drawing.Point(84, 3);
            this.btnClearSend.Name = "btnClearSend";
            this.btnClearSend.Size = new System.Drawing.Size(75, 23);
            this.btnClearSend.TabIndex = 0;
            this.btnClearSend.Text = "清空发送区";
            this.btnClearSend.UseVisualStyleBackColor = true;
            this.btnClearSend.Click += new System.EventHandler(this.btnClearSend_Click);
            // 
            // btnSend
            // 
            this.btnSend.Location = new System.Drawing.Point(3, 3);
            this.btnSend.Name = "btnSend";
            this.btnSend.Size = new System.Drawing.Size(75, 23);
            this.btnSend.TabIndex = 1;
            this.btnSend.Text = "发送";
            this.btnSend.UseVisualStyleBackColor = true;
            this.btnSend.Click += new System.EventHandler(this.btnSend_Click);
            // 
            // tableLayoutPanel2
            // 
            this.tableLayoutPanel2.ColumnCount = 1;
            this.tableLayoutPanel2.ColumnStyles.Add(new System.Windows.Forms.ColumnStyle(System.Windows.Forms.SizeType.Percent, 100F));
            this.tableLayoutPanel2.Controls.Add(this.groupBox1, 0, 0);
            this.tableLayoutPanel2.Controls.Add(this.groupBox4, 0, 1);
            this.tableLayoutPanel2.Controls.Add(this.groupBox5, 0, 2);
            this.tableLayoutPanel2.Dock = System.Windows.Forms.DockStyle.Fill;
            this.tableLayoutPanel2.Location = new System.Drawing.Point(188, 3);
            this.tableLayoutPanel2.Name = "tableLayoutPanel2";
            this.tableLayoutPanel2.RowCount = 4;
            this.tableLayoutPanel2.RowStyles.Add(new System.Windows.Forms.RowStyle(System.Windows.Forms.SizeType.Absolute, 208F));
            this.tableLayoutPanel2.RowStyles.Add(new System.Windows.Forms.RowStyle(System.Windows.Forms.SizeType.Absolute, 91F));
            this.tableLayoutPanel2.RowStyles.Add(new System.Windows.Forms.RowStyle(System.Windows.Forms.SizeType.Absolute, 91F));
            this.tableLayoutPanel2.RowStyles.Add(new System.Windows.Forms.RowStyle(System.Windows.Forms.SizeType.Percent, 100F));
            this.tableLayoutPanel2.Size = new System.Drawing.Size(194, 206);
            this.tableLayoutPanel2.TabIndex = 2;
            // 
            // groupBox1
            // 
            this.groupBox1.Controls.Add(this.tableLayoutPanel4);
            this.groupBox1.Dock = System.Windows.Forms.DockStyle.Fill;
            this.groupBox1.Location = new System.Drawing.Point(3, 3);
            this.groupBox1.Name = "groupBox1";
            this.groupBox1.Size = new System.Drawing.Size(188, 202);
            this.groupBox1.TabIndex = 0;
            this.groupBox1.TabStop = false;
            this.groupBox1.Text = "串口配置";
            // 
            // tableLayoutPanel4
            // 
            this.tableLayoutPanel4.ColumnCount = 2;
            this.tableLayoutPanel4.ColumnStyles.Add(new System.Windows.Forms.ColumnStyle(System.Windows.Forms.SizeType.Absolute, 60F));
            this.tableLayoutPanel4.ColumnStyles.Add(new System.Windows.Forms.ColumnStyle(System.Windows.Forms.SizeType.Absolute, 122F));
            this.tableLayoutPanel4.Controls.Add(this.label3, 0, 0);
            this.tableLayoutPanel4.Controls.Add(this.cbPortName, 1, 0);
            this.tableLayoutPanel4.Controls.Add(this.label4, 0, 1);
            this.tableLayoutPanel4.Controls.Add(this.label5, 0, 2);
            this.tableLayoutPanel4.Controls.Add(this.label6, 0, 3);
            this.tableLayoutPanel4.Controls.Add(this.label7, 0, 4);
            this.tableLayoutPanel4.Controls.Add(this.label8, 0, 5);
            this.tableLayoutPanel4.Controls.Add(this.cbBaudRate, 1, 1);
            this.tableLayoutPanel4.Controls.Add(this.cbDataBits, 1, 2);
            this.tableLayoutPanel4.Controls.Add(this.cbStopBits, 1, 3);
            this.tableLayoutPanel4.Controls.Add(this.cbParity, 1, 4);
            this.tableLayoutPanel4.Controls.Add(this.btnOpen, 1, 5);
            this.tableLayoutPanel4.Dock = System.Windows.Forms.DockStyle.Top;
            this.tableLayoutPanel4.Location = new System.Drawing.Point(3, 17);
            this.tableLayoutPanel4.Name = "tableLayoutPanel4";
            this.tableLayoutPanel4.RowCount = 7;
            this.tableLayoutPanel4.RowStyles.Add(new System.Windows.Forms.RowStyle(System.Windows.Forms.SizeType.Absolute, 30F));
            this.tableLayoutPanel4.RowStyles.Add(new System.Windows.Forms.RowStyle(System.Windows.Forms.SizeType.Absolute, 30F));
            this.tableLayoutPanel4.RowStyles.Add(new System.Windows.Forms.RowStyle(System.Windows.Forms.SizeType.Absolute, 30F));
            this.tableLayoutPanel4.RowStyles.Add(new System.Windows.Forms.RowStyle(System.Windows.Forms.SizeType.Absolute, 30F));
            this.tableLayoutPanel4.RowStyles.Add(new System.Windows.Forms.RowStyle(System.Windows.Forms.SizeType.Absolute, 30F));
            this.tableLayoutPanel4.RowStyles.Add(new System.Windows.Forms.RowStyle(System.Windows.Forms.SizeType.Absolute, 30F));
            this.tableLayoutPanel4.RowStyles.Add(new System.Windows.Forms.RowStyle(System.Windows.Forms.SizeType.Absolute, 20F));
            this.tableLayoutPanel4.Size = new System.Drawing.Size(182, 179);
            this.tableLayoutPanel4.TabIndex = 1;
            // 
            // label3
            // 
            this.label3.Anchor = System.Windows.Forms.AnchorStyles.None;
            this.label3.AutoSize = true;
            this.label3.Location = new System.Drawing.Point(9, 9);
            this.label3.Name = "label3";
            this.label3.Size = new System.Drawing.Size(41, 12);
            this.label3.TabIndex = 0;
            this.label3.Text = "串口号";
            // 
            // cbPortName
            // 
            this.cbPortName.Anchor = System.Windows.Forms.AnchorStyles.Left;
            this.cbPortName.DropDownStyle = System.Windows.Forms.ComboBoxStyle.DropDownList;
            this.cbPortName.FormattingEnabled = true;
            this.cbPortName.Location = new System.Drawing.Point(63, 5);
            this.cbPortName.Name = "cbPortName";
            this.cbPortName.Size = new System.Drawing.Size(116, 20);
            this.cbPortName.TabIndex = 1;
            this.cbPortName.DropDown += new System.EventHandler(this.cbPortName_DropDown);
            // 
            // label4
            // 
            this.label4.Anchor = System.Windows.Forms.AnchorStyles.None;
            this.label4.AutoSize = true;
            this.label4.Location = new System.Drawing.Point(9, 39);
            this.label4.Name = "label4";
            this.label4.Size = new System.Drawing.Size(41, 12);
            this.label4.TabIndex = 2;
            this.label4.Text = "波特率";
            // 
            // label5
            // 
            this.label5.Anchor = System.Windows.Forms.AnchorStyles.None;
            this.label5.AutoSize = true;
            this.label5.Location = new System.Drawing.Point(9, 69);
            this.label5.Name = "label5";
            this.label5.Size = new System.Drawing.Size(41, 12);
            this.label5.TabIndex = 3;
            this.label5.Text = "数据位";
            // 
            // label6
            // 
            this.label6.Anchor = System.Windows.Forms.AnchorStyles.None;
            this.label6.AutoSize = true;
            this.label6.Location = new System.Drawing.Point(9, 99);
            this.label6.Name = "label6";
            this.label6.Size = new System.Drawing.Size(41, 12);
            this.label6.TabIndex = 4;
            this.label6.Text = "停止位";
            // 
            // label7
            // 
            this.label7.Anchor = System.Windows.Forms.AnchorStyles.None;
            this.label7.AutoSize = true;
            this.label7.Location = new System.Drawing.Point(9, 129);
            this.label7.Name = "label7";
            this.label7.Size = new System.Drawing.Size(41, 12);
            this.label7.TabIndex = 5;
            this.label7.Text = "校验位";
            // 
            // label8
            // 
            this.label8.Anchor = System.Windows.Forms.AnchorStyles.None;
            this.label8.AutoSize = true;
            this.label8.Location = new System.Drawing.Point(15, 159);
            this.label8.Name = "label8";
            this.label8.Size = new System.Drawing.Size(29, 12);
            this.label8.TabIndex = 6;
            this.label8.Text = "操作";
            // 
            // cbBaudRate
            // 
            this.cbBaudRate.Anchor = System.Windows.Forms.AnchorStyles.Left;
            this.cbBaudRate.FormattingEnabled = true;
            this.cbBaudRate.Items.AddRange(new object[] {
            "4800",
            "9600",
            "38400",
            "115200"});
            this.cbBaudRate.Location = new System.Drawing.Point(63, 35);
            this.cbBaudRate.Name = "cbBaudRate";
            this.cbBaudRate.Size = new System.Drawing.Size(116, 20);
            this.cbBaudRate.TabIndex = 7;
            // 
            // cbDataBits
            // 
            this.cbDataBits.Anchor = System.Windows.Forms.AnchorStyles.Left;
            this.cbDataBits.DropDownStyle = System.Windows.Forms.ComboBoxStyle.DropDownList;
            this.cbDataBits.FormattingEnabled = true;
            this.cbDataBits.Items.AddRange(new object[] {
            "5",
            "6",
            "7",
            "8"});
            this.cbDataBits.Location = new System.Drawing.Point(63, 65);
            this.cbDataBits.Name = "cbDataBits";
            this.cbDataBits.Size = new System.Drawing.Size(116, 20);
            this.cbDataBits.TabIndex = 8;
            // 
            // cbStopBits
            // 
            this.cbStopBits.Anchor = System.Windows.Forms.AnchorStyles.Left;
            this.cbStopBits.DropDownStyle = System.Windows.Forms.ComboBoxStyle.DropDownList;
            this.cbStopBits.FormattingEnabled = true;
            this.cbStopBits.Items.AddRange(new object[] {
            "1",
            "1.5",
            "2"});
            this.cbStopBits.Location = new System.Drawing.Point(63, 95);
            this.cbStopBits.Name = "cbStopBits";
            this.cbStopBits.Size = new System.Drawing.Size(116, 20);
            this.cbStopBits.TabIndex = 9;
            // 
            // cbParity
            // 
            this.cbParity.Anchor = System.Windows.Forms.AnchorStyles.Left;
            this.cbParity.DropDownStyle = System.Windows.Forms.ComboBoxStyle.DropDownList;
            this.cbParity.FormattingEnabled = true;
            this.cbParity.Items.AddRange(new object[] {
            "无",
            "奇校验",
            "偶校验"});
            this.cbParity.Location = new System.Drawing.Point(63, 125);
            this.cbParity.Name = "cbParity";
            this.cbParity.Size = new System.Drawing.Size(116, 20);
            this.cbParity.TabIndex = 10;
            // 
            // btnOpen
            // 
            this.btnOpen.Dock = System.Windows.Forms.DockStyle.Fill;
            this.btnOpen.Location = new System.Drawing.Point(63, 153);
            this.btnOpen.Name = "btnOpen";
            this.btnOpen.Size = new System.Drawing.Size(116, 24);
            this.btnOpen.TabIndex = 11;
            this.btnOpen.Text = "打开串口";
            this.btnOpen.UseVisualStyleBackColor = true;
            this.btnOpen.Click += new System.EventHandler(this.btnOpen_Click);
            // 
            // groupBox4
            // 
            this.groupBox4.Controls.Add(this.tableLayoutPanel7);
            this.groupBox4.Dock = System.Windows.Forms.DockStyle.Fill;
            this.groupBox4.Location = new System.Drawing.Point(3, 211);
            this.groupBox4.Name = "groupBox4";
            this.groupBox4.Size = new System.Drawing.Size(188, 85);
            this.groupBox4.TabIndex = 1;
            this.groupBox4.TabStop = false;
            this.groupBox4.Text = "接收区配置";
            // 
            // tableLayoutPanel7
            // 
            this.tableLayoutPanel7.ColumnCount = 2;
            this.tableLayoutPanel7.ColumnStyles.Add(new System.Windows.Forms.ColumnStyle(System.Windows.Forms.SizeType.Absolute, 60F));
            this.tableLayoutPanel7.ColumnStyles.Add(new System.Windows.Forms.ColumnStyle(System.Windows.Forms.SizeType.Absolute, 122F));
            this.tableLayoutPanel7.Controls.Add(this.label1, 0, 0);
            this.tableLayoutPanel7.Controls.Add(this.cbReceiveMode, 1, 0);
            this.tableLayoutPanel7.Controls.Add(this.label2, 0, 1);
            this.tableLayoutPanel7.Controls.Add(this.cbReceiveCoding, 1, 1);
            this.tableLayoutPanel7.Dock = System.Windows.Forms.DockStyle.Top;
            this.tableLayoutPanel7.Location = new System.Drawing.Point(3, 17);
            this.tableLayoutPanel7.Name = "tableLayoutPanel7";
            this.tableLayoutPanel7.RowCount = 2;
            this.tableLayoutPanel7.RowStyles.Add(new System.Windows.Forms.RowStyle(System.Windows.Forms.SizeType.Absolute, 30F));
            this.tableLayoutPanel7.RowStyles.Add(new System.Windows.Forms.RowStyle(System.Windows.Forms.SizeType.Absolute, 30F));
            this.tableLayoutPanel7.Size = new System.Drawing.Size(182, 62);
            this.tableLayoutPanel7.TabIndex = 2;
            // 
            // label1
            // 
            this.label1.Anchor = System.Windows.Forms.AnchorStyles.None;
            this.label1.AutoSize = true;
            this.label1.Location = new System.Drawing.Point(3, 9);
            this.label1.Name = "label1";
            this.label1.Size = new System.Drawing.Size(53, 12);
            this.label1.TabIndex = 0;
            this.label1.Text = "接收模式";
            // 
            // cbReceiveMode
            // 
            this.cbReceiveMode.Anchor = System.Windows.Forms.AnchorStyles.Left;
            this.cbReceiveMode.DropDownStyle = System.Windows.Forms.ComboBoxStyle.DropDownList;
            this.cbReceiveMode.FormattingEnabled = true;
            this.cbReceiveMode.Items.AddRange(new object[] {
            "HEX模式",
            "文本模式"});
            this.cbReceiveMode.Location = new System.Drawing.Point(63, 5);
            this.cbReceiveMode.Name = "cbReceiveMode";
            this.cbReceiveMode.Size = new System.Drawing.Size(116, 20);
            this.cbReceiveMode.TabIndex = 1;
            this.cbReceiveMode.SelectedIndexChanged += new System.EventHandler(this.cbReceiveMode_SelectedIndexChanged);
            // 
            // label2
            // 
            this.label2.Anchor = System.Windows.Forms.AnchorStyles.None;
            this.label2.AutoSize = true;
            this.label2.Location = new System.Drawing.Point(3, 40);
            this.label2.Name = "label2";
            this.label2.Size = new System.Drawing.Size(53, 12);
            this.label2.TabIndex = 2;
            this.label2.Text = "文本编码";
            // 
            // cbReceiveCoding
            // 
            this.cbReceiveCoding.Anchor = System.Windows.Forms.AnchorStyles.Left;
            this.cbReceiveCoding.DropDownStyle = System.Windows.Forms.ComboBoxStyle.DropDownList;
            this.cbReceiveCoding.FormattingEnabled = true;
            this.cbReceiveCoding.Items.AddRange(new object[] {
            "GBK",
            "UTF-8"});
            this.cbReceiveCoding.Location = new System.Drawing.Point(63, 36);
            this.cbReceiveCoding.Name = "cbReceiveCoding";
            this.cbReceiveCoding.Size = new System.Drawing.Size(116, 20);
            this.cbReceiveCoding.TabIndex = 7;
            this.cbReceiveCoding.SelectedIndexChanged += new System.EventHandler(this.cbReceiveCoding_SelectedIndexChanged);
            // 
            // groupBox5
            // 
            this.groupBox5.Controls.Add(this.tableLayoutPanel8);
            this.groupBox5.Dock = System.Windows.Forms.DockStyle.Fill;
            this.groupBox5.Location = new System.Drawing.Point(3, 302);
            this.groupBox5.Name = "groupBox5";
            this.groupBox5.Size = new System.Drawing.Size(188, 85);
            this.groupBox5.TabIndex = 2;
            this.groupBox5.TabStop = false;
            this.groupBox5.Text = "发送区配置";
            this.groupBox5.Enter += new System.EventHandler(this.groupBox5_Enter);
            // 
            // tableLayoutPanel8
            // 
            this.tableLayoutPanel8.ColumnCount = 2;
            this.tableLayoutPanel8.ColumnStyles.Add(new System.Windows.Forms.ColumnStyle(System.Windows.Forms.SizeType.Absolute, 60F));
            this.tableLayoutPanel8.ColumnStyles.Add(new System.Windows.Forms.ColumnStyle(System.Windows.Forms.SizeType.Absolute, 122F));
            this.tableLayoutPanel8.Controls.Add(this.label9, 0, 0);
            this.tableLayoutPanel8.Controls.Add(this.cbSendMode, 1, 0);
            this.tableLayoutPanel8.Controls.Add(this.label10, 0, 1);
            this.tableLayoutPanel8.Controls.Add(this.cbSendCoding, 1, 1);
            this.tableLayoutPanel8.Dock = System.Windows.Forms.DockStyle.Top;
            this.tableLayoutPanel8.Location = new System.Drawing.Point(3, 17);
            this.tableLayoutPanel8.Name = "tableLayoutPanel8";
            this.tableLayoutPanel8.RowCount = 2;
            this.tableLayoutPanel8.RowStyles.Add(new System.Windows.Forms.RowStyle(System.Windows.Forms.SizeType.Absolute, 30F));
            this.tableLayoutPanel8.RowStyles.Add(new System.Windows.Forms.RowStyle(System.Windows.Forms.SizeType.Absolute, 30F));
            this.tableLayoutPanel8.Size = new System.Drawing.Size(182, 62);
            this.tableLayoutPanel8.TabIndex = 3;
            // 
            // label9
            // 
            this.label9.Anchor = System.Windows.Forms.AnchorStyles.None;
            this.label9.AutoSize = true;
            this.label9.Location = new System.Drawing.Point(3, 9);
            this.label9.Name = "label9";
            this.label9.Size = new System.Drawing.Size(53, 12);
            this.label9.TabIndex = 0;
            this.label9.Text = "发送模式";
            // 
            // cbSendMode
            // 
            this.cbSendMode.Anchor = System.Windows.Forms.AnchorStyles.Left;
            this.cbSendMode.DropDownStyle = System.Windows.Forms.ComboBoxStyle.DropDownList;
            this.cbSendMode.FormattingEnabled = true;
            this.cbSendMode.Items.AddRange(new object[] {
            "HEX模式",
            "文本模式"});
            this.cbSendMode.Location = new System.Drawing.Point(63, 5);
            this.cbSendMode.Name = "cbSendMode";
            this.cbSendMode.Size = new System.Drawing.Size(116, 20);
            this.cbSendMode.TabIndex = 1;
            this.cbSendMode.SelectedIndexChanged += new System.EventHandler(this.cbSendMode_SelectedIndexChanged);
            // 
            // label10
            // 
            this.label10.Anchor = System.Windows.Forms.AnchorStyles.None;
            this.label10.AutoSize = true;
            this.label10.Location = new System.Drawing.Point(3, 40);
            this.label10.Name = "label10";
            this.label10.Size = new System.Drawing.Size(53, 12);
            this.label10.TabIndex = 2;
            this.label10.Text = "文本编码";
            // 
            // cbSendCoding
            // 
            this.cbSendCoding.Anchor = System.Windows.Forms.AnchorStyles.Left;
            this.cbSendCoding.DropDownStyle = System.Windows.Forms.ComboBoxStyle.DropDownList;
            this.cbSendCoding.FormattingEnabled = true;
            this.cbSendCoding.Items.AddRange(new object[] {
            "GBK",
            "UTF-8"});
            this.cbSendCoding.Location = new System.Drawing.Point(63, 36);
            this.cbSendCoding.Name = "cbSendCoding";
            this.cbSendCoding.Size = new System.Drawing.Size(116, 20);
            this.cbSendCoding.TabIndex = 7;
            this.cbSendCoding.SelectedIndexChanged += new System.EventHandler(this.cbSendCoding_SelectedIndexChanged);
            // 
            // serialPort
            // 
            this.serialPort.DataReceived += new System.IO.Ports.SerialDataReceivedEventHandler(this.serialPort_DataReceived);
            // 
            // pictureBox1
            // 
            this.pictureBox1.ForeColor = System.Drawing.Color.Chartreuse;
            this.pictureBox1.Location = new System.Drawing.Point(727, 34);
            this.pictureBox1.Name = "pictureBox1";
            this.pictureBox1.Size = new System.Drawing.Size(645, 568);
            this.pictureBox1.TabIndex = 1;
            this.pictureBox1.TabStop = false;
            this.pictureBox1.Text = "Example";
            this.pictureBox1.Click += new System.EventHandler(this.pictureBox1_Click);
            // 
            // opencamera
            // 
            this.opencamera.Location = new System.Drawing.Point(3, 3);
            this.opencamera.Name = "opencamera";
            this.opencamera.Size = new System.Drawing.Size(78, 46);
            this.opencamera.TabIndex = 2;
            this.opencamera.Text = "打开相机";
            this.opencamera.UseVisualStyleBackColor = true;
            this.opencamera.Click += new System.EventHandler(this.capture_Click);
            // 
            // capture
            // 
            this.capture.Location = new System.Drawing.Point(197, 3);
            this.capture.Name = "capture";
            this.capture.Size = new System.Drawing.Size(74, 46);
            this.capture.TabIndex = 4;
            this.capture.Text = "拍照";
            this.capture.UseVisualStyleBackColor = true;
            this.capture.Click += new System.EventHandler(this.button2_Click);
            // 
            // comboBox1
            // 
            this.comboBox1.FormattingEnabled = true;
            this.comboBox1.Location = new System.Drawing.Point(97, 48);
            this.comboBox1.Name = "comboBox1";
            this.comboBox1.Size = new System.Drawing.Size(85, 20);
            this.comboBox1.TabIndex = 5;
            this.comboBox1.SelectedIndexChanged += new System.EventHandler(this.comboBox1_SelectedIndexChanged);
            // 
            // label11
            // 
            this.label11.AutoSize = true;
            this.label11.Location = new System.Drawing.Point(3, 0);
            this.label11.Name = "label11";
            this.label11.Size = new System.Drawing.Size(53, 12);
            this.label11.TabIndex = 6;
            this.label11.Text = "曝光设置";
            this.label11.Click += new System.EventHandler(this.label11_Click);
            // 
            // textBox1
            // 
            this.textBox1.Location = new System.Drawing.Point(97, 23);
            this.textBox1.Name = "textBox1";
            this.textBox1.Size = new System.Drawing.Size(70, 21);
            this.textBox1.TabIndex = 7;
            this.textBox1.Text = "32";
            this.textBox1.TextChanged += new System.EventHandler(this.textBox1_TextChanged);
            // 
            // radioButton1
            // 
            this.radioButton1.AutoSize = true;
            this.radioButton1.Location = new System.Drawing.Point(3, 23);
            this.radioButton1.Name = "radioButton1";
            this.radioButton1.Size = new System.Drawing.Size(47, 16);
            this.radioButton1.TabIndex = 9;
            this.radioButton1.TabStop = true;
            this.radioButton1.Text = "手动";
            this.radioButton1.UseVisualStyleBackColor = true;
            this.radioButton1.CheckedChanged += new System.EventHandler(this.radioButton1_CheckedChanged);
            // 
            // radioButton2
            // 
            this.radioButton2.AutoSize = true;
            this.radioButton2.Location = new System.Drawing.Point(3, 48);
            this.radioButton2.Name = "radioButton2";
            this.radioButton2.Size = new System.Drawing.Size(47, 16);
            this.radioButton2.TabIndex = 10;
            this.radioButton2.TabStop = true;
            this.radioButton2.Text = "自选";
            this.radioButton2.UseVisualStyleBackColor = true;
            // 
            // label12
            // 
            this.label12.AutoSize = true;
            this.label12.Location = new System.Drawing.Point(221, 325);
            this.label12.Name = "label12";
            this.label12.Size = new System.Drawing.Size(65, 60);
            this.label12.TabIndex = 12;
            this.label12.Text = "当前曝光：\r\n\r\n当前增益：\r\n\r\n当前伽马：";
            this.label12.Click += new System.EventHandler(this.label12_Click);
            // 
            // button1
            // 
            this.button1.Location = new System.Drawing.Point(100, 3);
            this.button1.Name = "button1";
            this.button1.Size = new System.Drawing.Size(74, 46);
            this.button1.TabIndex = 13;
            this.button1.Text = "开始";
            this.button1.UseVisualStyleBackColor = true;
            this.button1.Click += new System.EventHandler(this.button1_Click);
            // 
            // button2
            // 
            this.button2.Location = new System.Drawing.Point(294, 3);
            this.button2.Name = "button2";
            this.button2.Size = new System.Drawing.Size(78, 46);
            this.button2.TabIndex = 14;
            this.button2.Text = "暂停";
            this.button2.UseVisualStyleBackColor = true;
            this.button2.Click += new System.EventHandler(this.button2_Click_1);
            // 
            // textBox2
            // 
            this.textBox2.Location = new System.Drawing.Point(3, 36);
            this.textBox2.Multiline = true;
            this.textBox2.Name = "textBox2";
            this.textBox2.ReadOnly = true;
            this.textBox2.Size = new System.Drawing.Size(171, 27);
            this.textBox2.TabIndex = 15;
            // 
            // button3
            // 
            this.button3.Location = new System.Drawing.Point(180, 3);
            this.button3.Name = "button3";
            this.button3.Size = new System.Drawing.Size(75, 26);
            this.button3.TabIndex = 16;
            this.button3.Text = "浏览";
            this.button3.UseVisualStyleBackColor = true;
            this.button3.Click += new System.EventHandler(this.button3_Click);
            // 
            // label13
            // 
            this.label13.Location = new System.Drawing.Point(3, 0);
            this.label13.Name = "label13";
            this.label13.Size = new System.Drawing.Size(117, 22);
            this.label13.TabIndex = 17;
            this.label13.Text = "当前图片数：";
            this.label13.Click += new System.EventHandler(this.label13_Click);
            // 
            // button4
            // 
            this.button4.Location = new System.Drawing.Point(180, 36);
            this.button4.Name = "button4";
            this.button4.Size = new System.Drawing.Size(75, 23);
            this.button4.TabIndex = 18;
            this.button4.Text = "打开文件夹";
            this.button4.UseVisualStyleBackColor = true;
            this.button4.Click += new System.EventHandler(this.button4_Click);
            // 
            // LED1
            // 
            this.LED1.Location = new System.Drawing.Point(608, 666);
            this.LED1.Name = "LED1";
            this.LED1.Size = new System.Drawing.Size(104, 24);
            this.LED1.TabIndex = 21;
            this.LED1.Text = "LED1";
            this.LED1.UseVisualStyleBackColor = true;
            this.LED1.CheckedChanged += new System.EventHandler(this.LED1_CheckedChanged);
            // 
            // T1
            // 
            this.T1.Enabled = false;
            this.T1.Location = new System.Drawing.Point(657, 666);
            this.T1.Name = "T1";
            this.T1.Size = new System.Drawing.Size(46, 21);
            this.T1.TabIndex = 22;
            this.T1.Text = "0";
            this.T1.TextChanged += new System.EventHandler(this.T1_TextChanged);
            // 
            // T2
            // 
            this.T2.Enabled = false;
            this.T2.Location = new System.Drawing.Point(768, 666);
            this.T2.Name = "T2";
            this.T2.Size = new System.Drawing.Size(46, 21);
            this.T2.TabIndex = 24;
            this.T2.Text = "0";
            this.T2.TextChanged += new System.EventHandler(this.textBox3_TextChanged_1);
            // 
            // LED2
            // 
            this.LED2.Location = new System.Drawing.Point(718, 666);
            this.LED2.Name = "LED2";
            this.LED2.Size = new System.Drawing.Size(55, 24);
            this.LED2.TabIndex = 23;
            this.LED2.Text = "LED2";
            this.LED2.UseVisualStyleBackColor = true;
            this.LED2.CheckedChanged += new System.EventHandler(this.checkBox1_CheckedChanged);
            // 
            // T4
            // 
            this.T4.Enabled = false;
            this.T4.Location = new System.Drawing.Point(984, 666);
            this.T4.Name = "T4";
            this.T4.Size = new System.Drawing.Size(46, 21);
            this.T4.TabIndex = 28;
            this.T4.Text = "0";
            // 
            // LED4
            // 
            this.LED4.Location = new System.Drawing.Point(934, 666);
            this.LED4.Name = "LED4";
            this.LED4.Size = new System.Drawing.Size(55, 24);
            this.LED4.TabIndex = 27;
            this.LED4.Text = "LED4";
            this.LED4.UseVisualStyleBackColor = true;
            // 
            // T3
            // 
            this.T3.Enabled = false;
            this.T3.Location = new System.Drawing.Point(873, 666);
            this.T3.Name = "T3";
            this.T3.Size = new System.Drawing.Size(46, 21);
            this.T3.TabIndex = 26;
            this.T3.Text = "0";
            // 
            // LED3
            // 
            this.LED3.Location = new System.Drawing.Point(824, 666);
            this.LED3.Name = "LED3";
            this.LED3.Size = new System.Drawing.Size(104, 24);
            this.LED3.TabIndex = 25;
            this.LED3.Text = "LED3";
            this.LED3.UseVisualStyleBackColor = true;
            // 
            // T8
            // 
            this.T8.Enabled = false;
            this.T8.Location = new System.Drawing.Point(984, 693);
            this.T8.Name = "T8";
            this.T8.Size = new System.Drawing.Size(46, 21);
            this.T8.TabIndex = 36;
            this.T8.Text = "0";
            // 
            // LED8
            // 
            this.LED8.Location = new System.Drawing.Point(934, 693);
            this.LED8.Name = "LED8";
            this.LED8.Size = new System.Drawing.Size(55, 24);
            this.LED8.TabIndex = 35;
            this.LED8.Text = "LED8";
            this.LED8.UseVisualStyleBackColor = true;
            this.LED8.CheckedChanged += new System.EventHandler(this.checkBox1_CheckedChanged_1);
            // 
            // T7
            // 
            this.T7.Enabled = false;
            this.T7.Location = new System.Drawing.Point(873, 693);
            this.T7.Name = "T7";
            this.T7.Size = new System.Drawing.Size(46, 21);
            this.T7.TabIndex = 34;
            this.T7.Text = "0";
            // 
            // LED7
            // 
            this.LED7.Location = new System.Drawing.Point(824, 693);
            this.LED7.Name = "LED7";
            this.LED7.Size = new System.Drawing.Size(104, 24);
            this.LED7.TabIndex = 33;
            this.LED7.Text = "LED7";
            this.LED7.UseVisualStyleBackColor = true;
            // 
            // T6
            // 
            this.T6.Enabled = false;
            this.T6.Location = new System.Drawing.Point(768, 693);
            this.T6.Name = "T6";
            this.T6.Size = new System.Drawing.Size(46, 21);
            this.T6.TabIndex = 32;
            this.T6.Text = "0";
            // 
            // LED6
            // 
            this.LED6.Location = new System.Drawing.Point(718, 693);
            this.LED6.Name = "LED6";
            this.LED6.Size = new System.Drawing.Size(55, 24);
            this.LED6.TabIndex = 31;
            this.LED6.Text = "LED6";
            this.LED6.UseVisualStyleBackColor = true;
            // 
            // T5
            // 
            this.T5.Enabled = false;
            this.T5.Location = new System.Drawing.Point(657, 693);
            this.T5.Name = "T5";
            this.T5.Size = new System.Drawing.Size(46, 21);
            this.T5.TabIndex = 30;
            this.T5.Text = "0";
            // 
            // LED5
            // 
            this.LED5.Location = new System.Drawing.Point(608, 693);
            this.LED5.Name = "LED5";
            this.LED5.Size = new System.Drawing.Size(104, 24);
            this.LED5.TabIndex = 29;
            this.LED5.Text = "LED5";
            this.LED5.UseVisualStyleBackColor = true;
            // 
            // T16
            // 
            this.T16.Enabled = false;
            this.T16.Location = new System.Drawing.Point(984, 747);
            this.T16.Name = "T16";
            this.T16.Size = new System.Drawing.Size(46, 21);
            this.T16.TabIndex = 52;
            this.T16.Text = "0";
            // 
            // LED16
            // 
            this.LED16.Location = new System.Drawing.Point(934, 747);
            this.LED16.Name = "LED16";
            this.LED16.Size = new System.Drawing.Size(55, 24);
            this.LED16.TabIndex = 51;
            this.LED16.Text = "LED16";
            this.LED16.UseVisualStyleBackColor = true;
            // 
            // T15
            // 
            this.T15.Enabled = false;
            this.T15.Location = new System.Drawing.Point(873, 747);
            this.T15.Name = "T15";
            this.T15.Size = new System.Drawing.Size(46, 21);
            this.T15.TabIndex = 50;
            this.T15.Text = "0";
            // 
            // LED15
            // 
            this.LED15.Location = new System.Drawing.Point(824, 747);
            this.LED15.Name = "LED15";
            this.LED15.Size = new System.Drawing.Size(104, 24);
            this.LED15.TabIndex = 49;
            this.LED15.Text = "LED15";
            this.LED15.UseVisualStyleBackColor = true;
            // 
            // T14
            // 
            this.T14.Enabled = false;
            this.T14.Location = new System.Drawing.Point(768, 747);
            this.T14.Name = "T14";
            this.T14.Size = new System.Drawing.Size(46, 21);
            this.T14.TabIndex = 48;
            this.T14.Text = "0";
            // 
            // LED14
            // 
            this.LED14.Location = new System.Drawing.Point(718, 747);
            this.LED14.Name = "LED14";
            this.LED14.Size = new System.Drawing.Size(55, 24);
            this.LED14.TabIndex = 47;
            this.LED14.Text = "LED14";
            this.LED14.UseVisualStyleBackColor = true;
            // 
            // T13
            // 
            this.T13.Enabled = false;
            this.T13.Location = new System.Drawing.Point(657, 747);
            this.T13.Name = "T13";
            this.T13.Size = new System.Drawing.Size(46, 21);
            this.T13.TabIndex = 46;
            this.T13.Text = "0";
            // 
            // LED13
            // 
            this.LED13.Location = new System.Drawing.Point(608, 747);
            this.LED13.Name = "LED13";
            this.LED13.Size = new System.Drawing.Size(104, 24);
            this.LED13.TabIndex = 45;
            this.LED13.Text = "LED13";
            this.LED13.UseVisualStyleBackColor = true;
            // 
            // T12
            // 
            this.T12.Enabled = false;
            this.T12.Location = new System.Drawing.Point(984, 720);
            this.T12.Name = "T12";
            this.T12.Size = new System.Drawing.Size(46, 21);
            this.T12.TabIndex = 44;
            this.T12.Text = "0";
            // 
            // LED12
            // 
            this.LED12.Location = new System.Drawing.Point(934, 720);
            this.LED12.Name = "LED12";
            this.LED12.Size = new System.Drawing.Size(55, 24);
            this.LED12.TabIndex = 43;
            this.LED12.Text = "LED12";
            this.LED12.UseVisualStyleBackColor = true;
            // 
            // T11
            // 
            this.T11.Enabled = false;
            this.T11.Location = new System.Drawing.Point(873, 720);
            this.T11.Name = "T11";
            this.T11.Size = new System.Drawing.Size(46, 21);
            this.T11.TabIndex = 42;
            this.T11.Text = "0";
            // 
            // LED11
            // 
            this.LED11.Location = new System.Drawing.Point(824, 720);
            this.LED11.Name = "LED11";
            this.LED11.Size = new System.Drawing.Size(104, 24);
            this.LED11.TabIndex = 41;
            this.LED11.Text = "LED11";
            this.LED11.UseVisualStyleBackColor = true;
            // 
            // T10
            // 
            this.T10.Enabled = false;
            this.T10.Location = new System.Drawing.Point(768, 720);
            this.T10.Name = "T10";
            this.T10.Size = new System.Drawing.Size(46, 21);
            this.T10.TabIndex = 40;
            this.T10.Text = "0";
            // 
            // LED10
            // 
            this.LED10.Location = new System.Drawing.Point(718, 720);
            this.LED10.Name = "LED10";
            this.LED10.Size = new System.Drawing.Size(55, 24);
            this.LED10.TabIndex = 39;
            this.LED10.Text = "LED10";
            this.LED10.UseVisualStyleBackColor = true;
            // 
            // T9
            // 
            this.T9.Enabled = false;
            this.T9.Location = new System.Drawing.Point(657, 720);
            this.T9.Name = "T9";
            this.T9.Size = new System.Drawing.Size(46, 21);
            this.T9.TabIndex = 38;
            this.T9.Text = "0";
            // 
            // LED9
            // 
            this.LED9.Location = new System.Drawing.Point(608, 720);
            this.LED9.Name = "LED9";
            this.LED9.Size = new System.Drawing.Size(104, 24);
            this.LED9.TabIndex = 37;
            this.LED9.Text = "LED9";
            this.LED9.UseVisualStyleBackColor = true;
            // 
            // button5
            // 
            this.button5.Location = new System.Drawing.Point(1053, 688);
            this.button5.Name = "button5";
            this.button5.Size = new System.Drawing.Size(66, 53);
            this.button5.TabIndex = 53;
            this.button5.Text = "确定";
            this.button5.UseVisualStyleBackColor = true;
            this.button5.Click += new System.EventHandler(this.button5_Click);
            // 
            // tableLayoutPanel9
            // 
            this.tableLayoutPanel9.ColumnCount = 4;
            this.tableLayoutPanel9.ColumnStyles.Add(new System.Windows.Forms.ColumnStyle(System.Windows.Forms.SizeType.Percent, 16.66667F));
            this.tableLayoutPanel9.ColumnStyles.Add(new System.Windows.Forms.ColumnStyle(System.Windows.Forms.SizeType.Percent, 16.66667F));
            this.tableLayoutPanel9.ColumnStyles.Add(new System.Windows.Forms.ColumnStyle(System.Windows.Forms.SizeType.Percent, 16.66667F));
            this.tableLayoutPanel9.ColumnStyles.Add(new System.Windows.Forms.ColumnStyle(System.Windows.Forms.SizeType.Percent, 16.66667F));
            this.tableLayoutPanel9.Controls.Add(this.button1, 1, 0);
            this.tableLayoutPanel9.Controls.Add(this.button2, 3, 0);
            this.tableLayoutPanel9.Controls.Add(this.opencamera, 0, 0);
            this.tableLayoutPanel9.Controls.Add(this.capture, 2, 0);
            this.tableLayoutPanel9.Location = new System.Drawing.Point(15, 259);
            this.tableLayoutPanel9.Name = "tableLayoutPanel9";
            this.tableLayoutPanel9.RowCount = 1;
            this.tableLayoutPanel9.RowStyles.Add(new System.Windows.Forms.RowStyle(System.Windows.Forms.SizeType.Percent, 28.04233F));
            this.tableLayoutPanel9.Size = new System.Drawing.Size(389, 54);
            this.tableLayoutPanel9.TabIndex = 54;
            // 
            // tableLayoutPanel10
            // 
            this.tableLayoutPanel10.ColumnCount = 2;
            this.tableLayoutPanel10.ColumnStyles.Add(new System.Windows.Forms.ColumnStyle(System.Windows.Forms.SizeType.Percent, 50F));
            this.tableLayoutPanel10.ColumnStyles.Add(new System.Windows.Forms.ColumnStyle(System.Windows.Forms.SizeType.Percent, 50F));
            this.tableLayoutPanel10.Controls.Add(this.textBox1, 1, 1);
            this.tableLayoutPanel10.Controls.Add(this.radioButton2, 0, 2);
            this.tableLayoutPanel10.Controls.Add(this.radioButton1, 0, 1);
            this.tableLayoutPanel10.Controls.Add(this.label11, 0, 0);
            this.tableLayoutPanel10.Controls.Add(this.comboBox1, 1, 2);
            this.tableLayoutPanel10.Location = new System.Drawing.Point(18, 319);
            this.tableLayoutPanel10.Name = "tableLayoutPanel10";
            this.tableLayoutPanel10.RowCount = 3;
            this.tableLayoutPanel10.RowStyles.Add(new System.Windows.Forms.RowStyle(System.Windows.Forms.SizeType.Percent, 28.98551F));
            this.tableLayoutPanel10.RowStyles.Add(new System.Windows.Forms.RowStyle(System.Windows.Forms.SizeType.Percent, 36.23188F));
            this.tableLayoutPanel10.RowStyles.Add(new System.Windows.Forms.RowStyle(System.Windows.Forms.SizeType.Percent, 33.33333F));
            this.tableLayoutPanel10.RowStyles.Add(new System.Windows.Forms.RowStyle(System.Windows.Forms.SizeType.Absolute, 20F));
            this.tableLayoutPanel10.Size = new System.Drawing.Size(188, 69);
            this.tableLayoutPanel10.TabIndex = 55;
            // 
            // tableLayoutPanel11
            // 
            this.tableLayoutPanel11.ColumnCount = 2;
            this.tableLayoutPanel11.ColumnStyles.Add(new System.Windows.Forms.ColumnStyle());
            this.tableLayoutPanel11.ColumnStyles.Add(new System.Windows.Forms.ColumnStyle(System.Windows.Forms.SizeType.Percent, 100F));
            this.tableLayoutPanel11.Controls.Add(this.button4, 1, 1);
            this.tableLayoutPanel11.Controls.Add(this.textBox2, 0, 1);
            this.tableLayoutPanel11.Controls.Add(this.label13, 0, 0);
            this.tableLayoutPanel11.Controls.Add(this.button3, 1, 0);
            this.tableLayoutPanel11.Location = new System.Drawing.Point(15, 466);
            this.tableLayoutPanel11.Name = "tableLayoutPanel11";
            this.tableLayoutPanel11.RowCount = 2;
            this.tableLayoutPanel11.RowStyles.Add(new System.Windows.Forms.RowStyle(System.Windows.Forms.SizeType.Percent, 50F));
            this.tableLayoutPanel11.RowStyles.Add(new System.Windows.Forms.RowStyle(System.Windows.Forms.SizeType.Percent, 50F));
            this.tableLayoutPanel11.Size = new System.Drawing.Size(294, 66);
            this.tableLayoutPanel11.TabIndex = 56;
            // 
            // tableLayoutPanel12
            // 
            this.tableLayoutPanel12.ColumnCount = 2;
            this.tableLayoutPanel12.ColumnStyles.Add(new System.Windows.Forms.ColumnStyle(System.Windows.Forms.SizeType.Percent, 14.96479F));
            this.tableLayoutPanel12.ColumnStyles.Add(new System.Windows.Forms.ColumnStyle(System.Windows.Forms.SizeType.Percent, 85.03521F));
            this.tableLayoutPanel12.Controls.Add(this.imginfo, 1, 0);
            this.tableLayoutPanel12.Controls.Add(this.chart1, 1, 1);
            this.tableLayoutPanel12.Controls.Add(this.checkBox2, 0, 1);
            this.tableLayoutPanel12.Controls.Add(this.checkBox1, 0, 0);
            this.tableLayoutPanel12.Location = new System.Drawing.Point(15, 542);
            this.tableLayoutPanel12.Name = "tableLayoutPanel12";
            this.tableLayoutPanel12.RowCount = 2;
            this.tableLayoutPanel12.RowStyles.Add(new System.Windows.Forms.RowStyle(System.Windows.Forms.SizeType.Percent, 25.6F));
            this.tableLayoutPanel12.RowStyles.Add(new System.Windows.Forms.RowStyle(System.Windows.Forms.SizeType.Percent, 74.4F));
            this.tableLayoutPanel12.Size = new System.Drawing.Size(568, 235);
            this.tableLayoutPanel12.TabIndex = 58;
            // 
            // imginfo
            // 
            this.imginfo.Location = new System.Drawing.Point(88, 0);
            this.imginfo.Name = "imginfo";
            this.imginfo.Size = new System.Drawing.Size(131, 60);
            this.imginfo.TabIndex = 1;
            this.imginfo.Text = "最小值：\r\n\r\n最大值：\r\n\r\n平均值：";
            // 
            // chart1
            // 
            chartArea1.Name = "ChartArea1";
            this.chart1.ChartAreas.Add(chartArea1);
            legend1.Name = "Legend1";
            this.chart1.Legends.Add(legend1);
            this.chart1.Location = new System.Drawing.Point(88, 63);
            this.chart1.Name = "chart1";
            series1.ChartArea = "ChartArea1";
            series1.Legend = "Legend1";
            series1.Name = "Series1";
            this.chart1.Series.Add(series1);
            this.chart1.Size = new System.Drawing.Size(477, 159);
            this.chart1.TabIndex = 2;
            this.chart1.Text = "chart1";
            // 
            // checkBox2
            // 
            this.checkBox2.Location = new System.Drawing.Point(3, 63);
            this.checkBox2.Name = "checkBox2";
            this.checkBox2.Size = new System.Drawing.Size(78, 36);
            this.checkBox2.TabIndex = 3;
            this.checkBox2.Text = "自动曝光";
            this.checkBox2.UseVisualStyleBackColor = true;
            this.checkBox2.CheckedChanged += new System.EventHandler(this.checkBox2_CheckedChanged);
            // 
            // checkBox1
            // 
            this.checkBox1.Location = new System.Drawing.Point(3, 3);
            this.checkBox1.Name = "checkBox1";
            this.checkBox1.Size = new System.Drawing.Size(78, 36);
            this.checkBox1.TabIndex = 0;
            this.checkBox1.Text = "自动LED";
            this.checkBox1.UseVisualStyleBackColor = true;
            this.checkBox1.CheckedChanged += new System.EventHandler(this.checkBox1_CheckedChanged_2);
            // 
            // tableLayoutPanel13
            // 
            this.tableLayoutPanel13.ColumnCount = 2;
            this.tableLayoutPanel13.ColumnStyles.Add(new System.Windows.Forms.ColumnStyle());
            this.tableLayoutPanel13.ColumnStyles.Add(new System.Windows.Forms.ColumnStyle(System.Windows.Forms.SizeType.Percent, 100F));
            this.tableLayoutPanel13.Controls.Add(this.button6, 1, 1);
            this.tableLayoutPanel13.Controls.Add(this.textBox3, 0, 1);
            this.tableLayoutPanel13.Location = new System.Drawing.Point(0, 0);
            this.tableLayoutPanel13.Name = "tableLayoutPanel13";
            this.tableLayoutPanel13.RowCount = 2;
            this.tableLayoutPanel13.RowStyles.Add(new System.Windows.Forms.RowStyle(System.Windows.Forms.SizeType.Absolute, 20F));
            this.tableLayoutPanel13.RowStyles.Add(new System.Windows.Forms.RowStyle(System.Windows.Forms.SizeType.Absolute, 20F));
            this.tableLayoutPanel13.Size = new System.Drawing.Size(200, 100);
            this.tableLayoutPanel13.TabIndex = 0;
            // 
            // button6
            // 
            this.button6.Location = new System.Drawing.Point(180, 23);
            this.button6.Name = "button6";
            this.button6.Size = new System.Drawing.Size(17, 23);
            this.button6.TabIndex = 18;
            this.button6.Text = "打开文件夹";
            this.button6.UseVisualStyleBackColor = true;
            // 
            // textBox3
            // 
            this.textBox3.Location = new System.Drawing.Point(3, 23);
            this.textBox3.Multiline = true;
            this.textBox3.Name = "textBox3";
            this.textBox3.ReadOnly = true;
            this.textBox3.Size = new System.Drawing.Size(171, 47);
            this.textBox3.TabIndex = 15;
            // 
            // label14
            // 
            this.label14.Location = new System.Drawing.Point(3, 0);
            this.label14.Name = "label14";
            this.label14.Size = new System.Drawing.Size(79, 14);
            this.label14.TabIndex = 17;
            this.label14.Text = "当前图片数：";
            // 
            // comboBox2
            // 
            this.comboBox2.Anchor = System.Windows.Forms.AnchorStyles.Left;
            this.comboBox2.DropDownStyle = System.Windows.Forms.ComboBoxStyle.DropDownList;
            this.comboBox2.FormattingEnabled = true;
            this.comboBox2.Items.AddRange(new object[] {
            "1600*900",
            "1360*768",
            "1280*720",
            "1024*768",
            "640*480",
            "320*240"});
            this.comboBox2.Location = new System.Drawing.Point(432, 435);
            this.comboBox2.Name = "comboBox2";
            this.comboBox2.Size = new System.Drawing.Size(107, 20);
            this.comboBox2.TabIndex = 12;
            this.comboBox2.SelectedIndexChanged += new System.EventHandler(this.comboBox2_SelectedIndexChanged);
            // 
            // textBox4
            // 
            this.textBox4.Location = new System.Drawing.Point(389, 493);
            this.textBox4.Name = "textBox4";
            this.textBox4.Size = new System.Drawing.Size(51, 21);
            this.textBox4.TabIndex = 60;
            // 
            // textBox5
            // 
            this.textBox5.Location = new System.Drawing.Point(471, 493);
            this.textBox5.Name = "textBox5";
            this.textBox5.Size = new System.Drawing.Size(55, 21);
            this.textBox5.TabIndex = 61;
            // 
            // label15
            // 
            this.label15.Location = new System.Drawing.Point(409, 477);
            this.label15.Name = "label15";
            this.label15.Size = new System.Drawing.Size(20, 18);
            this.label15.TabIndex = 62;
            this.label15.Text = "宽";
            // 
            // label16
            // 
            this.label16.Location = new System.Drawing.Point(482, 477);
            this.label16.Name = "label16";
            this.label16.Size = new System.Drawing.Size(21, 18);
            this.label16.TabIndex = 63;
            this.label16.Text = "高";
            // 
            // label17
            // 
            this.label17.Location = new System.Drawing.Point(446, 496);
            this.label17.Name = "label17";
            this.label17.Size = new System.Drawing.Size(19, 15);
            this.label17.TabIndex = 64;
            this.label17.Text = "×";
            // 
            // button7
            // 
            this.button7.Location = new System.Drawing.Point(532, 486);
            this.button7.Name = "button7";
            this.button7.Size = new System.Drawing.Size(51, 28);
            this.button7.TabIndex = 65;
            this.button7.Text = "确定";
            this.button7.UseVisualStyleBackColor = true;
            this.button7.Click += new System.EventHandler(this.button7_Click);
            // 
            // checkBox3
            // 
            this.checkBox3.Location = new System.Drawing.Point(315, 489);
            this.checkBox3.Name = "checkBox3";
            this.checkBox3.Size = new System.Drawing.Size(68, 28);
            this.checkBox3.TabIndex = 66;
            this.checkBox3.Text = "自定义";
            this.checkBox3.UseVisualStyleBackColor = true;
            // 
            // comboBox3
            // 
            this.comboBox3.Anchor = System.Windows.Forms.AnchorStyles.Left;
            this.comboBox3.DropDownStyle = System.Windows.Forms.ComboBoxStyle.DropDownList;
            this.comboBox3.FormattingEnabled = true;
            this.comboBox3.Items.AddRange(new object[] {
            "10",
            "50",
            "100",
            "1000"});
            this.comboBox3.Location = new System.Drawing.Point(107, 405);
            this.comboBox3.Name = "comboBox3";
            this.comboBox3.Size = new System.Drawing.Size(107, 20);
            this.comboBox3.TabIndex = 67;
            // 
            // label18
            // 
            this.label18.Location = new System.Drawing.Point(15, 408);
            this.label18.Name = "label18";
            this.label18.Size = new System.Drawing.Size(82, 23);
            this.label18.TabIndex = 68;
            this.label18.Text = "自动曝光幅度";
            // 
            // checkBox4
            // 
            this.checkBox4.Location = new System.Drawing.Point(379, 405);
            this.checkBox4.Name = "checkBox4";
            this.checkBox4.Size = new System.Drawing.Size(85, 28);
            this.checkBox4.TabIndex = 69;
            this.checkBox4.Text = "相机";
            this.checkBox4.UseVisualStyleBackColor = true;
            // 
            // label19
            // 
            this.label19.Location = new System.Drawing.Point(444, 394);
            this.label19.Name = "label19";
            this.label19.Size = new System.Drawing.Size(100, 23);
            this.label19.TabIndex = 71;
            this.label19.Text = "LED序号";
            // 
            // comboBox4
            // 
            this.comboBox4.Anchor = System.Windows.Forms.AnchorStyles.Left;
            this.comboBox4.DropDownStyle = System.Windows.Forms.ComboBoxStyle.DropDownList;
            this.comboBox4.FormattingEnabled = true;
            this.comboBox4.Items.AddRange(new object[] {
            "2",
            "3",
            "4",
            "5",
            "6",
            "7",
            "8",
            "9",
            "10",
            "11",
            "12",
            "13",
            "14"});
            this.comboBox4.Location = new System.Drawing.Point(440, 409);
            this.comboBox4.Name = "comboBox4";
            this.comboBox4.Size = new System.Drawing.Size(67, 20);
            this.comboBox4.TabIndex = 72;
            // 
            // button8
            // 
            this.button8.Location = new System.Drawing.Point(646, 405);
            this.button8.Name = "button8";
            this.button8.Size = new System.Drawing.Size(75, 23);
            this.button8.TabIndex = 73;
            this.button8.Text = "确定";
            this.button8.UseVisualStyleBackColor = true;
            this.button8.Click += new System.EventHandler(this.button8_Click);
            // 
            // comboBox5
            // 
            this.comboBox5.Anchor = System.Windows.Forms.AnchorStyles.Left;
            this.comboBox5.DropDownStyle = System.Windows.Forms.ComboBoxStyle.DropDownList;
            this.comboBox5.FormattingEnabled = true;
            this.comboBox5.Items.AddRange(new object[] {
            "1",
            "2",
            "5",
            "10"});
            this.comboBox5.Location = new System.Drawing.Point(513, 408);
            this.comboBox5.Name = "comboBox5";
            this.comboBox5.Size = new System.Drawing.Size(67, 20);
            this.comboBox5.TabIndex = 74;
            // 
            // label20
            // 
            this.label20.Location = new System.Drawing.Point(513, 394);
            this.label20.Name = "label20";
            this.label20.Size = new System.Drawing.Size(67, 17);
            this.label20.TabIndex = 75;
            this.label20.Text = "LED间隔";
            // 
            // label21
            // 
            this.label21.Location = new System.Drawing.Point(379, 383);
            this.label21.Name = "label21";
            this.label21.Size = new System.Drawing.Size(42, 19);
            this.label21.TabIndex = 76;
            this.label21.Text = "标定区";
            // 
            // comboBox6
            // 
            this.comboBox6.Anchor = System.Windows.Forms.AnchorStyles.Left;
            this.comboBox6.DropDownStyle = System.Windows.Forms.ComboBoxStyle.DropDownList;
            this.comboBox6.FormattingEnabled = true;
            this.comboBox6.Items.AddRange(new object[] {
            "100",
            "500",
            "1000",
            "2000",
            "5000",
            "10000"});
            this.comboBox6.Location = new System.Drawing.Point(586, 408);
            this.comboBox6.Name = "comboBox6";
            this.comboBox6.Size = new System.Drawing.Size(54, 20);
            this.comboBox6.TabIndex = 77;
            // 
            // label22
            // 
            this.label22.Location = new System.Drawing.Point(586, 394);
            this.label22.Name = "label22";
            this.label22.RightToLeft = System.Windows.Forms.RightToLeft.No;
            this.label22.Size = new System.Drawing.Size(54, 15);
            this.label22.TabIndex = 78;
            this.label22.Text = "采样间隔";
            // 
            // label23
            // 
            this.label23.Location = new System.Drawing.Point(90, 780);
            this.label23.Name = "label23";
            this.label23.Size = new System.Drawing.Size(67, 17);
            this.label23.TabIndex = 81;
            this.label23.Text = "LED间隔";
            // 
            // comboBox7
            // 
            this.comboBox7.Anchor = System.Windows.Forms.AnchorStyles.Left;
            this.comboBox7.DropDownStyle = System.Windows.Forms.ComboBoxStyle.DropDownList;
            this.comboBox7.FormattingEnabled = true;
            this.comboBox7.Items.AddRange(new object[] {
            "1",
            "2",
            "5",
            "10"});
            this.comboBox7.Location = new System.Drawing.Point(90, 794);
            this.comboBox7.Name = "comboBox7";
            this.comboBox7.Size = new System.Drawing.Size(67, 20);
            this.comboBox7.TabIndex = 80;
            // 
            // comboBox8
            // 
            this.comboBox8.Anchor = System.Windows.Forms.AnchorStyles.Left;
            this.comboBox8.DropDownStyle = System.Windows.Forms.ComboBoxStyle.DropDownList;
            this.comboBox8.FormattingEnabled = true;
            this.comboBox8.Items.AddRange(new object[] {
            "2",
            "3",
            "4",
            "5",
            "6",
            "7",
            "8",
            "9",
            "10",
            "11",
            "12",
            "13",
            "14"});
            this.comboBox8.Location = new System.Drawing.Point(15, 794);
            this.comboBox8.Name = "comboBox8";
            this.comboBox8.Size = new System.Drawing.Size(67, 20);
            this.comboBox8.TabIndex = 84;
            // 
            // label24
            // 
            this.label24.Location = new System.Drawing.Point(19, 779);
            this.label24.Name = "label24";
            this.label24.Size = new System.Drawing.Size(51, 12);
            this.label24.TabIndex = 83;
            this.label24.Text = "LED序号";
            // 
            // button9
            // 
            this.button9.Location = new System.Drawing.Point(234, 790);
            this.button9.Name = "button9";
            this.button9.Size = new System.Drawing.Size(75, 23);
            this.button9.TabIndex = 85;
            this.button9.Text = "确定";
            this.button9.UseVisualStyleBackColor = true;
            // 
            // label25
            // 
            this.label25.Location = new System.Drawing.Point(163, 779);
            this.label25.Name = "label25";
            this.label25.RightToLeft = System.Windows.Forms.RightToLeft.No;
            this.label25.Size = new System.Drawing.Size(54, 15);
            this.label25.TabIndex = 87;
            this.label25.Text = "采样间隔";
            // 
            // comboBox9
            // 
            this.comboBox9.Anchor = System.Windows.Forms.AnchorStyles.Left;
            this.comboBox9.DropDownStyle = System.Windows.Forms.ComboBoxStyle.DropDownList;
            this.comboBox9.FormattingEnabled = true;
            this.comboBox9.Items.AddRange(new object[] {
            "100",
            "500",
            "1000",
            "2000",
            "5000",
            "10000"});
            this.comboBox9.Location = new System.Drawing.Point(163, 793);
            this.comboBox9.Name = "comboBox9";
            this.comboBox9.Size = new System.Drawing.Size(54, 20);
            this.comboBox9.TabIndex = 86;
            // 
            // label26
            // 
            this.label26.AutoSize = true;
            this.label26.Location = new System.Drawing.Point(312, 780);
            this.label26.Name = "label26";
            this.label26.Size = new System.Drawing.Size(71, 36);
            this.label26.TabIndex = 88;
            this.label26.Text = "LED Index：\r\n\r\nLED Value：";
            // 
            // button10
            // 
            this.button10.Location = new System.Drawing.Point(646, 435);
            this.button10.Name = "button10";
            this.button10.Size = new System.Drawing.Size(75, 23);
            this.button10.TabIndex = 89;
            this.button10.Text = "暂停";
            this.button10.UseVisualStyleBackColor = true;
            this.button10.Click += new System.EventHandler(this.button10_Click);
            // 
            // Form1
            // 
            this.AutoScaleDimensions = new System.Drawing.SizeF(6F, 12F);
            this.AutoScaleMode = System.Windows.Forms.AutoScaleMode.Font;
            this.AutoSize = true;
            this.ClientSize = new System.Drawing.Size(1416, 925);
            this.Controls.Add(this.button10);
            this.Controls.Add(this.label26);
            this.Controls.Add(this.label25);
            this.Controls.Add(this.comboBox9);
            this.Controls.Add(this.button9);
            this.Controls.Add(this.comboBox8);
            this.Controls.Add(this.label24);
            this.Controls.Add(this.label23);
            this.Controls.Add(this.comboBox7);
            this.Controls.Add(this.label22);
            this.Controls.Add(this.comboBox6);
            this.Controls.Add(this.label21);
            this.Controls.Add(this.label20);
            this.Controls.Add(this.comboBox5);
            this.Controls.Add(this.button8);
            this.Controls.Add(this.comboBox4);
            this.Controls.Add(this.label19);
            this.Controls.Add(this.checkBox4);
            this.Controls.Add(this.label18);
            this.Controls.Add(this.comboBox3);
            this.Controls.Add(this.checkBox3);
            this.Controls.Add(this.button7);
            this.Controls.Add(this.label17);
            this.Controls.Add(this.label16);
            this.Controls.Add(this.label15);
            this.Controls.Add(this.textBox5);
            this.Controls.Add(this.textBox4);
            this.Controls.Add(this.tableLayoutPanel12);
            this.Controls.Add(this.comboBox2);
            this.Controls.Add(this.tableLayoutPanel11);
            this.Controls.Add(this.tableLayoutPanel10);
            this.Controls.Add(this.tableLayoutPanel9);
            this.Controls.Add(this.button5);
            this.Controls.Add(this.T16);
            this.Controls.Add(this.LED16);
            this.Controls.Add(this.T15);
            this.Controls.Add(this.LED15);
            this.Controls.Add(this.T14);
            this.Controls.Add(this.LED14);
            this.Controls.Add(this.T13);
            this.Controls.Add(this.LED13);
            this.Controls.Add(this.T12);
            this.Controls.Add(this.LED12);
            this.Controls.Add(this.T11);
            this.Controls.Add(this.LED11);
            this.Controls.Add(this.T10);
            this.Controls.Add(this.LED10);
            this.Controls.Add(this.T9);
            this.Controls.Add(this.LED9);
            this.Controls.Add(this.T8);
            this.Controls.Add(this.LED8);
            this.Controls.Add(this.T7);
            this.Controls.Add(this.LED7);
            this.Controls.Add(this.T6);
            this.Controls.Add(this.LED6);
            this.Controls.Add(this.T5);
            this.Controls.Add(this.LED5);
            this.Controls.Add(this.T4);
            this.Controls.Add(this.LED4);
            this.Controls.Add(this.T3);
            this.Controls.Add(this.LED3);
            this.Controls.Add(this.T2);
            this.Controls.Add(this.LED2);
            this.Controls.Add(this.T1);
            this.Controls.Add(this.LED1);
            this.Controls.Add(this.label12);
            this.Controls.Add(this.pictureBox1);
            this.Controls.Add(this.tableLayoutPanel1);
            this.Icon = ((System.Drawing.Icon)(resources.GetObject("$this.Icon")));
            this.Name = "Form1";
            this.Text = "串口助手 V1.1";
            this.Load += new System.EventHandler(this.Form1_Load);
            this.tableLayoutPanel1.ResumeLayout(false);
            this.tableLayoutPanel3.ResumeLayout(false);
            this.groupBox2.ResumeLayout(false);
            this.tableLayoutPanel5.ResumeLayout(false);
            this.tableLayoutPanel5.PerformLayout();
            this.flowLayoutPanel1.ResumeLayout(false);
            this.groupBox3.ResumeLayout(false);
            this.tableLayoutPanel6.ResumeLayout(false);
            this.tableLayoutPanel6.PerformLayout();
            this.flowLayoutPanel2.ResumeLayout(false);
            this.tableLayoutPanel2.ResumeLayout(false);
            this.groupBox1.ResumeLayout(false);
            this.tableLayoutPanel4.ResumeLayout(false);
            this.tableLayoutPanel4.PerformLayout();
            this.groupBox4.ResumeLayout(false);
            this.tableLayoutPanel7.ResumeLayout(false);
            this.tableLayoutPanel7.PerformLayout();
            this.groupBox5.ResumeLayout(false);
            this.tableLayoutPanel8.ResumeLayout(false);
            this.tableLayoutPanel8.PerformLayout();
            ((System.ComponentModel.ISupportInitialize)(this.pictureBox1)).EndInit();
            this.tableLayoutPanel9.ResumeLayout(false);
            this.tableLayoutPanel10.ResumeLayout(false);
            this.tableLayoutPanel10.PerformLayout();
            this.tableLayoutPanel11.ResumeLayout(false);
            this.tableLayoutPanel11.PerformLayout();
            this.tableLayoutPanel12.ResumeLayout(false);
            ((System.ComponentModel.ISupportInitialize)(this.chart1)).EndInit();
            this.tableLayoutPanel13.ResumeLayout(false);
            this.tableLayoutPanel13.PerformLayout();
            this.ResumeLayout(false);
            this.PerformLayout();

        }

        private System.Windows.Forms.Button button10;

        private System.Windows.Forms.Label label26;

        private System.Windows.Forms.Label label25;
        private System.Windows.Forms.ComboBox comboBox9;

        private System.Windows.Forms.Button button9;

        private System.Windows.Forms.ComboBox comboBox8;
        private System.Windows.Forms.Label label24;

        private System.Windows.Forms.Label label23;
        private System.Windows.Forms.ComboBox comboBox7;

        private System.Windows.Forms.Label label22;

        private System.Windows.Forms.ComboBox comboBox6;

        private System.Windows.Forms.Label label20;
        private System.Windows.Forms.Label label21;

        private System.Windows.Forms.Button button8;
        private System.Windows.Forms.ComboBox comboBox5;

        private System.Windows.Forms.ComboBox comboBox4;

        private System.Windows.Forms.CheckBox checkBox4;
        private System.Windows.Forms.Label label19;

        private System.Windows.Forms.ComboBox comboBox3;
        private System.Windows.Forms.Label label18;

        private System.Windows.Forms.CheckBox checkBox3;

        private System.Windows.Forms.Button button7;

        private System.Windows.Forms.TextBox textBox5;
        private System.Windows.Forms.Label label15;
        private System.Windows.Forms.Label label16;
        private System.Windows.Forms.Label label17;

        private System.Windows.Forms.TextBox textBox4;

        private System.Windows.Forms.TableLayoutPanel tableLayoutPanel13;
        private System.Windows.Forms.Button button6;
        private System.Windows.Forms.TextBox textBox3;
        private System.Windows.Forms.Label label14;

        private System.Windows.Forms.ComboBox comboBox2;

        private System.Windows.Forms.CheckBox checkBox2;

        private System.Windows.Forms.DataVisualization.Charting.Chart chart1;

        private System.Windows.Forms.Label imginfo;

        private System.Windows.Forms.CheckBox checkBox1;

        private System.Windows.Forms.TableLayoutPanel tableLayoutPanel12;

        private System.Windows.Forms.TableLayoutPanel tableLayoutPanel11;

        private System.Windows.Forms.TableLayoutPanel tableLayoutPanel10;

        private System.Windows.Forms.TableLayoutPanel tableLayoutPanel9;

        private System.Windows.Forms.Button button5;

        private System.Windows.Forms.TextBox T4;
        public System.Windows.Forms.CheckBox LED4;
        private System.Windows.Forms.TextBox T3;
        public System.Windows.Forms.CheckBox LED3;
        private System.Windows.Forms.TextBox T8;
        public System.Windows.Forms.CheckBox LED8;
        private System.Windows.Forms.TextBox T7;
        public System.Windows.Forms.CheckBox LED7;
        private System.Windows.Forms.TextBox T6;
        public System.Windows.Forms.CheckBox LED6;
        private System.Windows.Forms.TextBox T5;
        public System.Windows.Forms.CheckBox LED5;
        private System.Windows.Forms.TextBox T16;
        public System.Windows.Forms.CheckBox LED16;
        private System.Windows.Forms.TextBox T15;
        public System.Windows.Forms.CheckBox LED15;
        private System.Windows.Forms.TextBox T14;
        public System.Windows.Forms.CheckBox LED14;
        private System.Windows.Forms.TextBox T13;
        public System.Windows.Forms.CheckBox LED13;
        private System.Windows.Forms.TextBox T12;
        public System.Windows.Forms.CheckBox LED12;
        private System.Windows.Forms.TextBox T11;
        public System.Windows.Forms.CheckBox LED11;
        private System.Windows.Forms.TextBox T10;
        public System.Windows.Forms.CheckBox LED10;
        private System.Windows.Forms.TextBox T9;
        public System.Windows.Forms.CheckBox LED9;

        public System.Windows.Forms.CheckBox LED1;
        private System.Windows.Forms.TextBox T1;

        private System.Windows.Forms.TextBox T2;

        public System.Windows.Forms.CheckBox LED2;
        private System.Windows.Forms.TextBox t1;

        private System.Windows.Forms.Button button4;

        private System.Windows.Forms.Label label13;

        private System.Windows.Forms.Button button3;

        private System.Windows.Forms.TextBox textBox2;

        #endregion

        private System.Windows.Forms.TableLayoutPanel tableLayoutPanel1;
        private System.Windows.Forms.TableLayoutPanel tableLayoutPanel3;
        private System.Windows.Forms.GroupBox groupBox2;
        private System.Windows.Forms.GroupBox groupBox3;
        private System.Windows.Forms.TableLayoutPanel tableLayoutPanel2;
        private System.Windows.Forms.GroupBox groupBox1;
        private System.Windows.Forms.TableLayoutPanel tableLayoutPanel4;
        private System.Windows.Forms.Label label3;
        private System.Windows.Forms.ComboBox cbPortName;
        private System.Windows.Forms.Label label4;
        private System.Windows.Forms.Label label5;
        private System.Windows.Forms.Label label6;
        private System.Windows.Forms.Label label7;
        private System.Windows.Forms.Label label8;
        private System.Windows.Forms.ComboBox cbBaudRate;
        private System.Windows.Forms.ComboBox cbDataBits;
        private System.Windows.Forms.ComboBox cbStopBits;
        private System.Windows.Forms.ComboBox cbParity;
        private System.Windows.Forms.GroupBox groupBox4;
        private System.Windows.Forms.TableLayoutPanel tableLayoutPanel5;
        private System.Windows.Forms.TextBox tbReceive;
        private System.Windows.Forms.FlowLayoutPanel flowLayoutPanel1;
        private System.Windows.Forms.Button btnClearReceive;
        private System.Windows.Forms.TableLayoutPanel tableLayoutPanel6;
        private System.Windows.Forms.TextBox tbSend;
        private System.Windows.Forms.FlowLayoutPanel flowLayoutPanel2;
        private System.Windows.Forms.Button btnClearSend;
        private System.Windows.Forms.GroupBox groupBox5;
        private System.Windows.Forms.TableLayoutPanel tableLayoutPanel7;
        private System.Windows.Forms.Label label1;
        private System.Windows.Forms.ComboBox cbReceiveMode;
        private System.Windows.Forms.Label label2;
        private System.Windows.Forms.ComboBox cbReceiveCoding;
        private System.Windows.Forms.TableLayoutPanel tableLayoutPanel8;
        private System.Windows.Forms.Label label9;
        private System.Windows.Forms.ComboBox cbSendMode;
        private System.Windows.Forms.Label label10;
        private System.Windows.Forms.ComboBox cbSendCoding;
        private System.IO.Ports.SerialPort serialPort;
        private System.Windows.Forms.Button btnSend;
        private System.Windows.Forms.Button btnOpen;
        private System.Windows.Forms.PictureBox pictureBox1;
        private System.Windows.Forms.Button opencamera;
        private System.Windows.Forms.Button capture;
        private System.Windows.Forms.ComboBox comboBox1;
        private System.Windows.Forms.Label label11;
        private System.Windows.Forms.TextBox textBox1;
        private System.Windows.Forms.RadioButton radioButton1;
        private System.Windows.Forms.RadioButton radioButton2;
        private System.Windows.Forms.Label label12;
        private System.Windows.Forms.Button button1;
        private System.Windows.Forms.Button button2;
    }
}

