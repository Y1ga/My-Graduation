#include "stm32f10x.h"                  // Device header
#include "Delay.h"
#include "OLED.h"
#include "Timer.h"
#include "PWM.h"
#include "Serial.h"

int main(void)
{
	// Initialize peripherals
	PWM_Init(1000);
	Serial_Init();
	//  113, 127, 131, 137
	//  139, 149, 151, 157, 
	//  163, 167, 173, 179, 
	//  181, 191, 193, 197, 199
//	int ch1[4] = {113, 127, 131, 137};
//	int ch2[4] = {139, 149, 151, 157};
//	int ch3[4] = {163, 167, 173, 179};
		int ch1[4] = {100, 110, 120, 130};
	int ch2[4] = {140, 150, 160, 170};
	int ch3[4] = {180, 190, 200, 210};
	// 最低频率11H
	
	PWM_SetFrequency(TIM1, ch1[0]*1000 );
	PWM_SetFrequency(TIM2,  ch1[1]*1000);
	PWM_SetFrequency(TIM3,  ch1[2]*1000); 
	PWM_SetFrequency(TIM4, ch1[3]*1000);

////	// MCU #1
PWM_SetFrequency(TIM1, 30*1000);  // LED5: 158kHz
PWM_SetFrequency(TIM2, 50*10000);  // LED6: 168kHz
PWM_SetFrequency(TIM3, 70*1000);  // LED7: 178kHz
PWM_SetFrequency(TIM4, 110*1000);  // LED8: 188kHz
//////	/	// MCU #2
//	PWM_SetFrequency(TIM1, 130*1000);  // LED9: 198kHz
//PWM_SetFrequency(TIM2, 170*1000);  // LED10: 208kHz
//PWM_SetFrequency(TIM3, 190*1000);  // LED11: 218kHz
//PWM_SetFrequency(TIM4, 230*1000);  // LED12: 228kHz
// //MCU #3
//	PWM_SetFrequency(TIM1, 270*1000);  // LED9: 198kHz
//PWM_SetFrequency(TIM2, 290*1000);  // LED10: 208kHz
//PWM_SetFrequency(TIM3, 310*1000);  // LED11: 218kHz
//PWM_SetFrequency(TIM4, 370*1000);  // LED12: 228kHz
	int duty_cycle = 0;
	// A11
		int flag[4] = {1,	1, 0, 0};
	TIM_SetCompare4(TIM1, flag[0] * duty_cycle);
	// A0
	TIM_SetCompare1(TIM2, flag[1] * duty_cycle);
	// A6
	TIM_SetCompare1(TIM3, flag[2] * duty_cycle);
	// B6
		TIM_SetCompare1(TIM4, flag[3] * duty_cycle);
		// 注意！MCU2是COMPARE 2!
//TIM_SetCompare2(TIM4, flag[3] * duty_cycle);
	while(1)
	{
		// Continuously call the handler. 
		// This function is now non-blocking and will process any received serial data
		// without halting the CPU.
		HandleReceivedLine();
		
	}
}