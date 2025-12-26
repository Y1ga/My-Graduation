#ifndef __SERIAL_H
#define __SERIAL_H

#include <stdio.h>

// ??????
void Serial_Init(void);
void Serial_SendByte(uint8_t Byte);
void Serial_SendArray(uint8_t *Array, uint16_t Length);
void Serial_SendString(char *String);
uint32_t Serial_Pow(uint32_t X, uint32_t Y);
void Serial_SendNumber(uint32_t Number, uint8_t Length);
void Serial_Printf(char *format, ...);

// ??????
void HandleReceivedLine(void);

// ???????
void Timer_InitConfigs(void);
void Timer_ApplyConfig(uint8_t timer_index);
void Timer_StopAll(void);

// ??????
void Process_PWM_Command(uint8_t *data, uint16_t length);
void Process_Timer_Config_Command(uint8_t *data, uint16_t length);
void Process_Timer_Stop_Command(uint8_t *data, uint16_t length);
uint8_t Calculate_Checksum(uint8_t *data, uint16_t length);

#endif