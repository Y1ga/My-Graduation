#include "stm32f10x.h"                  // Device header
#include <stdio.h>
#include <stdarg.h>
#include <string.h>
#include "PWM.h"
#include "Serial.h"

// Define a buffer size for receiving serial data.
#define RX_BUFFER_SIZE 128 // Increased buffer size for safety

// Ring buffer structure for asynchronous data reception.
typedef struct {
    uint8_t buffer[RX_BUFFER_SIZE];
    volatile uint16_t head;
    volatile uint16_t tail;
} RingBuffer;

RingBuffer rx_buffer;

// Command definitions for different packet types
#define CMD_PWM_DATA    0x00  // PWM??? (??,????)
#define CMD_TIMER_CONFIG 0xA0 // ???????
#define CMD_TIMER_STOP  0xA1  // ???????

// Timer configuration structure
typedef struct {
    uint8_t enable;      // ????:1=??,0=??
    uint32_t frequency;  // ?? (Hz)
    uint8_t duty_value;  // ???? (?????????,?100)
} TimerConfig;

// Global timer configurations
TimerConfig timer_configs[4]; // TIM1, TIM2, TIM3, TIM4

// --- Ring Buffer Helper Functions ---
void RingBuffer_Init(RingBuffer *rb) {
    rb->head = 0;
    rb->tail = 0;
}

void RingBuffer_Put(RingBuffer *rb, uint8_t data) {
    uint16_t next_head = (rb->head + 1) % RX_BUFFER_SIZE;
    // Prevent buffer overflow
    if (next_head != rb->tail) {
        rb->buffer[rb->head] = data;
        rb->head = next_head;
    }
}

uint8_t RingBuffer_Get(RingBuffer *rb) {
    if (rb->tail == rb->head) return 0; // Buffer is empty
    uint8_t data = rb->buffer[rb->tail];
    rb->tail = (rb->tail + 1) % RX_BUFFER_SIZE;
    return data;
}

uint8_t RingBuffer_IsEmpty(RingBuffer *rb) {
    return rb->tail == rb->head;
}

// Calculate available data in ring buffer
uint16_t RingBuffer_Available(RingBuffer *rb) {
    return (rb->head - rb->tail + RX_BUFFER_SIZE) % RX_BUFFER_SIZE;
}

// --- Timer Control Functions ---
void Timer_InitConfigs(void) {
    // Initialize all timer configurations to disabled state
    for (int i = 0; i < 4; i++) {
        timer_configs[i].enable = 0;
        timer_configs[i].frequency = 1000;
        timer_configs[i].duty_value = 1;  // ??????1,????????
    }
}

void Timer_ApplyConfig(uint8_t timer_index) {
    if (timer_index >= 4) return;
    
    TimerConfig *config = &timer_configs[timer_index];
    TIM_TypeDef *timer;
    
    // Select the correct timer
    switch (timer_index) {
        case 0: timer = TIM1; break;
        case 1: timer = TIM2; break;
        case 2: timer = TIM3; break;
        case 3: timer = TIM4; break;
        default: return;
    }
    
    // ??????
    Serial_Printf("Config TIM%d: freq=%lu, duty_value=%d, enable=%d\r\n", 
                 timer_index + 1, config->frequency, config->duty_value, config->enable);
    
    if (config->enable) {
        // Enable and configure the timer
        PWM_SetFrequency(timer, config->frequency);
        
        // ????TIM1 - ???????????
        if (timer == TIM1) {
            // 1. ????BDTR??? (?????)
            // ??BDTR????????,????MOE?
            TIM1->BDTR = 0;  // ?????
            TIM1->BDTR |= TIM_BDTR_MOE;  // ????????
            
            // 2. ?????
            TIM_Cmd(TIM1, ENABLE);
            
            // 3. ??TIM1???4??? (????main??)
            TIM_SetCompare4(TIM1, config->duty_value);
            
            Serial_Printf("TIM1 CH4 compare value set to %d (BDTR=0x%04X)\r\n", config->duty_value, TIM1->BDTR);
        } else {
            // ??TIM2/TIM3/TIM4,????1 (????main??)
            TIM_Cmd(timer, ENABLE);
            TIM_SetCompare1(timer, config->duty_value);
            
            Serial_Printf("TIM%d CH1 compare value set to %d\r\n", timer_index + 1, config->duty_value);
        }
        
        Serial_Printf("TIM%d enabled successfully\r\n", timer_index + 1);
        
    } else {
        // Disable the timer
        Serial_Printf("Disabling TIM%d\r\n", timer_index + 1);
        
        if (timer == TIM1) {
            // ????? (??MOE?)
            TIM1->BDTR &= ~TIM_BDTR_MOE;
            // ??????0
            TIM_SetCompare4(TIM1, 0);
            // ?????
            TIM_Cmd(TIM1, DISABLE);
            Serial_Printf("TIM1 MOE disabled, CH4 set to 0 (BDTR=0x%04X)\r\n", TIM1->BDTR);
        } else {
            // ??????0
            TIM_SetCompare1(timer, 0);
            // ?????
            TIM_Cmd(timer, DISABLE);
            Serial_Printf("TIM%d CH1 set to 0, timer disabled\r\n", timer_index + 1);
        }
    }
    
    // ???????????
    if (timer == TIM1) {
        Serial_Printf("TIM1 Status - CR1:0x%04X, BDTR:0x%04X, MOE:%d, CCR4:%d\r\n", 
                     TIM1->CR1, TIM1->BDTR, (TIM1->BDTR & TIM_BDTR_MOE) ? 1 : 0, TIM1->CCR4);
    } else {
        Serial_Printf("TIM%d Status - CR1:0x%04X, CCR1:%d\r\n", 
                     timer_index + 1, timer->CR1, timer->CCR1);
    }
}

void Timer_StopAll(void) {
    Serial_Printf("Stopping all timers...\r\n");
    
    // Stop all timers by disabling them
    for (int i = 0; i < 4; i++) {
        timer_configs[i].enable = 0;
        Timer_ApplyConfig(i);
    }
    
    Serial_Printf("All timers stopped\r\n");
}

// --- Enhanced Timer Status Functions ---
void Timer_PrintStatus(void) {
    Serial_Printf("=== Timer Status ===\r\n");
    for (int i = 0; i < 4; i++) {
        TimerConfig *config = &timer_configs[i];
        Serial_Printf("TIM%d: %s, %luHz, duty_value=%d\r\n", 
                     i + 1, 
                     config->enable ? "ENABLED" : "DISABLED",
                     config->frequency, 
                     config->duty_value);
    }
    
    // ????TIM1??????
    Serial_Printf("TIM1 Registers:\r\n");
    Serial_Printf("  CR1: 0x%04X (CEN=%d)\r\n", TIM1->CR1, (TIM1->CR1 & TIM_CR1_CEN) ? 1 : 0);
    Serial_Printf("  BDTR: 0x%04X (MOE=%d)\r\n", TIM1->BDTR, (TIM1->BDTR & TIM_BDTR_MOE) ? 1 : 0);
    Serial_Printf("  ARR: %d, PSC: %d\r\n", TIM1->ARR, TIM1->PSC);
    Serial_Printf("  CCR1: %d, CCR2: %d, CCR3: %d, CCR4: %d\r\n", 
                 TIM1->CCR1, TIM1->CCR2, TIM1->CCR3, TIM1->CCR4);
    
    // ????????CCR1
    Serial_Printf("Other Timers CCR1:\r\n");
    Serial_Printf("  TIM2->CCR1: %d\r\n", TIM2->CCR1);
    Serial_Printf("  TIM3->CCR1: %d\r\n", TIM3->CCR1);
    Serial_Printf("  TIM4->CCR1: %d\r\n", TIM4->CCR1);
    Serial_Printf("==================\r\n");
}

// --- Command Processing Functions ---
uint8_t Calculate_Checksum(uint8_t *data, uint16_t length) {
    uint8_t checksum = 0;
    for (uint16_t i = 0; i < length; i++) {
        checksum += data[i];
    }
    return checksum;
}

void Process_PWM_Command(uint8_t *data, uint16_t length) {
    // Original PWM processing logic for 16-byte packets
    if (length >= 16) {
        Serial_Printf("PWM Command: setting 16 channels\r\n");
        
        // Set PWM for all 16 channels and echo the data back
        for (int i = 0; i < 16; i++) {
            PWM_SetDutyCycle(i + 1, data[i]);
            Serial_SendByte(data[i]); // Echo back the byte for confirmation
        }
        Serial_SendString("\r\n"); // Send a newline to indicate the packet was processed
        
        Serial_Printf("PWM channels updated\r\n");
    }
}

void Process_Timer_Config_Command(uint8_t *data, uint16_t length) {
    // Timer config packet: [CMD][TIM1_DATA][TIM2_DATA][TIM3_DATA][TIM4_DATA][CHECKSUM]
    // Each TIM_DATA: [ENABLE][FREQ_H][FREQ_M][FREQ_L][DUTY_VALUE]
    // Total length should be: 1 + (4 * 5) + 1 = 22 bytes
    
    Serial_Printf("Timer Config Command received (%d bytes)\r\n", length);
    
    if (length < 22) {
        Serial_Printf("Error: Timer config packet too short (%d bytes, expected 22)\r\n", length);
        return;
    }
    
    // Verify checksum
    uint8_t calculated_checksum = Calculate_Checksum(data, length - 1);
    uint8_t received_checksum = data[length - 1];
    
    if (calculated_checksum != received_checksum) {
        Serial_Printf("Error: Timer config checksum mismatch (calc:0x%02X, recv:0x%02X)\r\n", 
                     calculated_checksum, received_checksum);
        return;
    }
    
    Serial_Printf("Checksum OK (0x%02X)\r\n", received_checksum);
    Serial_Printf("Parsing timer configurations...\r\n");
    
    // Parse timer configurations
    for (int i = 0; i < 4; i++) {
        uint8_t offset = 1 + (i * 5); // Skip command byte, each timer has 5 bytes
        
        timer_configs[i].enable = data[offset];
        timer_configs[i].frequency = ((uint32_t)data[offset + 1] << 16) | 
                                   ((uint32_t)data[offset + 2] << 8) | 
                                   (uint32_t)data[offset + 3];
        timer_configs[i].duty_value = data[offset + 4];
        
        Serial_Printf("TIM%d parsed: enable=%d, freq=%lu, duty_value=%d\r\n",
                     i + 1, timer_configs[i].enable, timer_configs[i].frequency, timer_configs[i].duty_value);
        
        // Apply the configuration
        Timer_ApplyConfig(i);
    }
    
    // Print final status
    Timer_PrintStatus();
    
    // Echo back the entire received packet for confirmation
    Serial_Printf("Echo: ");
    for (int i = 0; i < length; i++) {
        Serial_SendByte(data[i]);
    }
    Serial_SendString("\r\n");
}

void Process_Timer_Stop_Command(uint8_t *data, uint16_t length) {
    // Stop all timers command: [0xA1][0xA1]
    Serial_Printf("Timer Stop Command received\r\n");
    
    if (length >= 2 && data[1] == 0xA1) {
        Timer_StopAll();
        Serial_Printf("All timers stopped successfully\r\n");
        
        // Echo back the command
        Serial_SendByte(data[0]);
        Serial_SendByte(data[1]);
        Serial_SendString("\r\n");
    } else {
        Serial_Printf("Error: Invalid stop command (expected A1 A1)\r\n");
    }
}

// --- Serial Initialization and Communication Functions ---

void Serial_Init(void)
{
	// Enable clocks for USART1 and GPIOA
	RCC_APB2PeriphClockCmd(RCC_APB2Periph_USART1, ENABLE);
	RCC_APB2PeriphClockCmd(RCC_APB2Periph_GPIOA, ENABLE);
	
	// Configure PA9 (TX) as Alternate Function Push-Pull
	GPIO_InitTypeDef GPIO_InitStructure;
	GPIO_InitStructure.GPIO_Mode = GPIO_Mode_AF_PP;
	GPIO_InitStructure.GPIO_Pin = GPIO_Pin_9;
	GPIO_InitStructure.GPIO_Speed = GPIO_Speed_50MHz;
	GPIO_Init(GPIOA, &GPIO_InitStructure);
	
	// Configure PA10 (RX) as Input Pull-Up
	GPIO_InitStructure.GPIO_Mode = GPIO_Mode_IPU;
	GPIO_InitStructure.GPIO_Pin = GPIO_Pin_10;
	GPIO_Init(GPIOA, &GPIO_InitStructure);
	
	// Configure USART1
	USART_InitTypeDef USART_InitStructure;
	USART_InitStructure.USART_BaudRate = 460800;
	USART_InitStructure.USART_HardwareFlowControl = USART_HardwareFlowControl_None;
	USART_InitStructure.USART_Mode = USART_Mode_Tx | USART_Mode_Rx;
	USART_InitStructure.USART_Parity = USART_Parity_No;
	USART_InitStructure.USART_StopBits = USART_StopBits_1;
	USART_InitStructure.USART_WordLength = USART_WordLength_8b;
	USART_Init(USART1, &USART_InitStructure);
	
	// Enable USART1 Receive Interrupt
	USART_ITConfig(USART1, USART_IT_RXNE, ENABLE);
	
	// Configure NVIC for USART1 Interrupt
	NVIC_PriorityGroupConfig(NVIC_PriorityGroup_2);
	NVIC_InitTypeDef NVIC_InitStructure;
	NVIC_InitStructure.NVIC_IRQChannel = USART1_IRQn;
	NVIC_InitStructure.NVIC_IRQChannelCmd = ENABLE;
	NVIC_InitStructure.NVIC_IRQChannelPreemptionPriority = 1;
	NVIC_InitStructure.NVIC_IRQChannelSubPriority = 1;
	NVIC_Init(&NVIC_InitStructure);
	
	// Initialize the ring buffer
	RingBuffer_Init(&rx_buffer);
	
	// Initialize timer configurations
	Timer_InitConfigs();
	
	// Enable USART1
	USART_Cmd(USART1, ENABLE);
	
	// ????
	Serial_Printf("\r\n=== STM32 Timer Controller Initialized ===\r\n");
	Serial_Printf("USART1: 460800 baud, 8N1\r\n");
	Serial_Printf("Commands: 0xA0=Timer Config, 0xA1=Stop All\r\n");
	Serial_Printf("Ready for commands...\r\n\r\n");
}

// OPTIMIZED USART1 Interrupt Service Routine
void USART1_IRQHandler(void)
{
	// Check if the Receive Data Not Empty interrupt has occurred
	if (USART_GetITStatus(USART1, USART_IT_RXNE) != RESET)
    {
        // A byte has been received. Put it directly into the ring buffer.
        RingBuffer_Put(&rx_buffer, USART_ReceiveData(USART1));
        // The interrupt flag is automatically cleared by reading the data register.
    }
}

// ENHANCED: This function now handles multiple command types
void HandleReceivedLine(void)
{
    static uint8_t packet_buffer[32]; // Increased buffer size for timer commands
    static uint8_t packet_index = 0;
    static uint8_t expected_length = 0;
    static uint8_t packet_type = CMD_PWM_DATA;

    // Process all characters currently in the buffer without blocking
    while (!RingBuffer_IsEmpty(&rx_buffer))
    {
        uint8_t receivedChar = RingBuffer_Get(&rx_buffer);

        // First byte determines the packet type and expected length
        if (packet_index == 0) {
            packet_buffer[0] = receivedChar;
            
            if (receivedChar == CMD_TIMER_CONFIG) {
                // Timer configuration command: 22 bytes total
                packet_type = CMD_TIMER_CONFIG;
                expected_length = 22;
                Serial_Printf("Expecting timer config packet (22 bytes)\r\n");
            } else if (receivedChar == CMD_TIMER_STOP) {
                // Timer stop command: 2 bytes total
                packet_type = CMD_TIMER_STOP;
                expected_length = 2;
                Serial_Printf("Expecting timer stop packet (2 bytes)\r\n");
            } else {
                // Default PWM data (no command header): 16 bytes
                packet_type = CMD_PWM_DATA;
                expected_length = 16;
                Serial_Printf("Expecting PWM data packet (16 bytes)\r\n");
            }
            packet_index = 1;
        } else {
            // Store subsequent bytes
            if (packet_index < sizeof(packet_buffer)) {
                packet_buffer[packet_index] = receivedChar;
                packet_index++;
            }
        }

        // Process complete packet when we have received all expected bytes
        if (packet_index >= expected_length) {
            Serial_Printf("Complete packet received (%d bytes), processing...\r\n", packet_index);
            
            switch (packet_type) {
                case CMD_TIMER_CONFIG:
                    Process_Timer_Config_Command(packet_buffer, packet_index);
                    break;
                    
                case CMD_TIMER_STOP:
                    Process_Timer_Stop_Command(packet_buffer, packet_index);
                    break;
                    
                case CMD_PWM_DATA:
                default:
                    Process_PWM_Command(packet_buffer, packet_index);
                    break;
            }
            
            // Reset for next packet
            packet_index = 0;
            expected_length = 0;
            packet_type = CMD_PWM_DATA;
            
            Serial_Printf("Ready for next command\r\n\r\n");
        }
    }
}

// --- Standard Serial Helper Functions (Unchanged) ---

void Serial_SendByte(uint8_t Byte)
{
	USART_SendData(USART1, Byte);
	while (USART_GetFlagStatus(USART1, USART_FLAG_TXE) == RESET);
}

void Serial_SendArray(uint8_t *Array, uint16_t Length)
{
	uint16_t i;
	for (i = 0; i < Length; i ++)
	{
		Serial_SendByte(Array[i]);
	}
}

void Serial_SendString(char *String)
{
	uint8_t i;
	for (i = 0; String[i] != '\0'; i ++)
	{
		Serial_SendByte(String[i]);
	}
}

uint32_t Serial_Pow(uint32_t X, uint32_t Y)
{
	uint32_t Result = 1;
	while (Y --)
	{
		Result *= X;
	}
	return Result;
}

void Serial_SendNumber(uint32_t Number, uint8_t Length)
{
	uint8_t i;
	for (i = 0; i < Length; i ++)
	{
		Serial_SendByte(Number / Serial_Pow(10, Length - i - 1) % 10 + '0');
	}
}

int fputc(int ch, FILE *f)
{
	Serial_SendByte(ch);
	return ch;
}

void Serial_Printf(char *format, ...)
{
	char String[100];
	va_list arg;
	va_start(arg, format);
	vsprintf(String, format, arg);
	va_end(arg);
	Serial_SendString(String);
}