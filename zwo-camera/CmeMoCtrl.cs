using System;
using System.IO.Ports;
using System.Text;
using System.Threading;
using System.Linq; // Added for LINQ extension methods

public class CmeMoCtrl
{
    private SerialPort serialPort;

    public CmeMoCtrl(string portName = "COM9", int baudRate = 9600)
    {
        serialPort = new SerialPort(portName, baudRate, Parity.None, 8, StopBits.One)
        {
            ReadTimeout = 1000
        };

        if (!serialPort.IsOpen)
        {
            serialPort.Open();
        }
    }

    public static int Wavelength2Position(double wavelength, double c, double Z, double T)
    {
        // c: 光栅校正系数,可读
        // Z: 光栅零位,可读
        // T: 光栅总步数,可读
        // wavelength: 目标波长
        double alpha = Math.Atan(wavelength / Math.Sqrt(c * c - wavelength * wavelength));
        double p;
        if (alpha < 0)
        {
            p = T + (0.5 * alpha * T / Math.PI) + Z;
        }
        else
        {
            p = (0.5 * alpha * T / Math.PI) + Z;
        }
        return (int)Math.Round(p);
    }

    public void ClearBuffers()
    {
        serialPort.DiscardInBuffer(); // 清空输入缓冲区
        serialPort.DiscardOutBuffer(); // 清空输出缓冲区
    }

    public string SendCommand(string command)
    {
        // ClearBuffers();
        serialPort.Write(command);
        StringBuilder response = new StringBuilder();
        string buffer = "";

        // 读取直到收到"OK\r"
        while (!buffer.EndsWith("OK\r"))
        {
            int readByte = serialPort.ReadByte();
            if (readByte != -1)
            {
                char character = (char)readByte;
                buffer += character;
                response.Append(character);
            }
            else
            {
                break; // 超时或没有更多数据
            }
        }

        return response.ToString().Trim();
    }

    public object CheckConnection()
    {
        string response = SendCommand("?\r");
        if (response.StartsWith("E01"))
        {
            return "Error: Connection not established. Please check the device.";
        }
        else if (response.Contains("OK"))
        {
            string[] data = response.Split('\r');
            return new
            {
                DeviceType = data[0],
                OutputType = data[1]
            };
        }
        else
        {
            return "Unexpected response.";
        }
    }

    public string MoveToWavelength(int position)
    {
        string command = $"B{position}\r";
        serialPort.Write(command);
        Console.WriteLine("Moving...");
        //while (true)
        //{
        //    string increment = serialPort.ReadTo("\r").Trim();
        //    if (increment == "0" || string.IsNullOrEmpty(increment))
        //    {
        //        Console.WriteLine("Move success");
        //        break;
        //    }
        //    Console.WriteLine($"Moving... Increment: {increment}");
        //}

        // 等待并确认完成
        string confirmation = "";
        while (!confirmation.EndsWith("OK\r"))
        {
            int readByte = serialPort.ReadByte();
            if (readByte != -1)
            {
                confirmation += (char)readByte;
            }
            else
            {
                break;
            }
        }
        return confirmation;
    }


    public void StartParameterQuery()
    {
        string response = SendCommand("Q\r");
        if (response.Contains("OK"))
        {
            Console.WriteLine("Started parameter query process.");
        }
        else
        {
            Console.WriteLine("Failed to start parameter query process.");
            Console.WriteLine("try again");
            EndParameterQuery();
            StartParameterQuery();
        }
    }

    public void EndParameterQuery()
    {
        string response = SendCommand("E\r");
        if (response.Contains("OK"))
        {
            Console.WriteLine("Ended parameter query process.");
        }
        else
        {
            Console.WriteLine("Failed to end parameter query process.");
        }
    }

    public object QuerySystemParameters()
    {
        string response = SendCommand("L\r");
        string[] data = response.Split('\r');
        if (data.Length == 5)
        {
            string instrumentId = data[0];
            string maxGratings = data[1];
            string totalSteps = data[2];
            string currentGratingGroup = data[3];
            return new
            {
                InstrumentId = instrumentId,
                MaxGratings = maxGratings,
                TotalSteps = totalSteps,
                CurrentGratingGroup = currentGratingGroup
            };
        }
        else
        {
            Console.WriteLine("Invalid response for system parameters.");
            return null;
        }
    }

    public object QueryGratingParameters(int gratingGroup, int gratingNumber)
    {
        if (0 <= gratingGroup && gratingGroup <= 3 && 1 <= gratingNumber && gratingNumber <= 3)
        {
            string command = $"T{gratingGroup}{gratingNumber}\r";
            string response = SendCommand(command);
            string[] data = response.Split('\r');

            if (data.Length == 5)
            {
                string zeroPosition = data[0];
                string correctionCoefficient = data[1];
                string linesCount = data[2];
                string flareWavelength = data[3];
                return new
                {
                    ZeroPosition = zeroPosition,
                    CorrectionCoefficient = correctionCoefficient,
                    LinesCount = linesCount,
                    FlareWavelength = flareWavelength
                };
            }
            else if (data[0] == "N")
            {
                Console.WriteLine("Selected grating parameters not set.");
                return null;
            }
            else if (data[0] == "E04")
            {
                Console.WriteLine("Selected grating group is out of range.");
                return null;
            }
            return null;
        }
        else
        {
            Console.WriteLine("Invalid grating group or number.");
            return null;
        }
    }

    public object QueryFilterGroup()
    {
        string response = SendCommand("F\r");
        string[] data = response.Split('\r');
        if (data.Length >= 2)
        {
            int number = int.Parse(data[0]);
            if (number > 1)
            {
                return new
                {
                    Status = "Filter parameters not set"
                };
            }
            else
            {
                int[] filterPositions = new int[data.Length - 5];
                for (int i = 4; i < data.Length - 1; i++)
                {
                    filterPositions[i - 4] = int.Parse(data[i]);
                }

                return new
                {
                    DataNumber = int.Parse(data[1]),
                    FilterPosition = int.Parse(data[2]),
                    TotalSteps = int.Parse(data[3]),
                    FilterPositions = filterPositions
                };
            }
        }
        else
        {
            return null;
        }
    }

    public object QueryFilterWorkingRange(int gratingNumber, int count)
    {
        if (1 <= gratingNumber && gratingNumber <= 3 && 1 <= count && count <= 8)
        {
            string command = $"p{gratingNumber}{count}\r";
            string response = SendCommand(command);
            string[] data = response.Split('\r');

            if (data.Length > 1)
            {
                int filterCount = int.Parse(data[0]); // 启用的滤光片数量
                var filters = new System.Collections.Generic.Dictionary<string, string>();
                for (int i = 1; i < data.Length - 1; i += 2)
                {
                    if (i + 1 < data.Length - 1)
                    {
                        filters[data[i]] = data[i + 1]; // lim_x 和 n_x
                    }
                }
                return new
                {
                    FilterCount = filterCount,
                    Filters = filters
                };
            }
            else
            {
                Console.WriteLine("Invalid response for filter working range.");
                return null;
            }
        }
        else
        {
            Console.WriteLine("Invalid grating number or count.");
            return null;
        }
    }

    public object QueryGratingSwitchPosition()
    {
        string response = SendCommand("P\r");
        string[] data = response.Split('\r');
        if (data.Length == 6)
        {
            string openMode = data[0];
            string posG1 = data[1];
            string posG2 = data[2];
            string posG3 = data[3];
            string posOpen = data[4];
            return new
            {
                OpenMode = openMode,
                PositionG1 = posG1,
                PositionG2 = posG2,
                PositionG3 = posG3,
                PositionOpen = posOpen
            };
        }
        else
        {
            Console.WriteLine("Invalid response for grating switch position.");
            return null;
        }
    }

    public string QueryParallelExitPosition()
    {
        string response = SendCommand("W\r");
        if (response.EndsWith("OK"))
        {
            return response.Split('\r')[0];
        }
        else
        {
            Console.WriteLine("Failed to query parallel exit position.");
            return null;
        }
    }

    public object QueryExitAutoSwitchWavelength()
    {
        string response = SendCommand("A\r");
        string[] data = response.Split('\r');
        if (data.Length == 4)
        {
            return new
            {
                Number1 = data[0],
                Number2 = data[1],
                Number3 = data[2]
            };
        }
        else
        {
            Console.WriteLine("Invalid response for exit auto switch wavelength.");
            return null;
        }
    }

    public void Reposition()
    {
        string response = SendCommand("H\r");
        Thread.Sleep(3000);
        if (response.Contains("OK"))
        {
            Console.WriteLine("Repositioning completed.");
        }
        else
        {
            Console.WriteLine("Failed to reposition.");
        }
    }

    public string QueryScanningSpeed()
    {
        string response = SendCommand("v\r");
        string speed = response.Split('\r')[0];
        return speed;
    }

    public string QueryCurrentPosition()
    {
        string response = SendCommand("b\r");
        // Alternative approach without using LINQ:
        string positionStr = response.Split('\r')[0];
        string position = "";
        foreach (char c in positionStr)
        {
            if (char.IsDigit(c))
            {
                position += c;
            }
        }
        return position;
    }

    public string QueryCurrentGrating()
    {
        string response = SendCommand("g\r");
        string gratingNumber = response.Split('\r')[0];
        return gratingNumber;
    }

    public void SwitchGrating(int gratingNumber)
    {
        string command = $"G{gratingNumber}\r";
        serialPort.Write(command);
        Console.WriteLine("Switching grating completed.");
    }

    public void SetSpeed(int speed)
    {
        if (0 <= speed && speed <= 255)
        {
            string command = $"V{speed}\r";
            string response = SendCommand(command);
            if (response.Contains("OK"))
            {
                Console.WriteLine($"Speed set to: {speed}");
            }
            else
            {
                Console.WriteLine("Failed to set speed.");
            }
        }
        else
        {
            Console.WriteLine("Speed must be in the range of 0 to 255.");
        }
    }

    public string SetGratingPosition(string openMode, int[] positions)
    {
        StringBuilder command = new StringBuilder($"l{openMode}");
        foreach (int pos in positions)
        {
            command.Append($"{pos}\r");
        }
        string response = SendCommand(command.ToString());
        return response;
    }

    public void Close()
    {
        serialPort.Close();
    }
}