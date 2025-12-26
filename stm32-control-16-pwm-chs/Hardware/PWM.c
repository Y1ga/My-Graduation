#include "stm32f10x.h"

// ?????? - ????SystemInit()??
// ????72MHz,APB1?36MHz,APB2?72MHz
#define F_CPU_APB1      72000000UL // APB1?? (?? TIM2, TIM3, TIM4)
#define F_CPU_APB2      72000000UL // APB2?? (?? TIM1)

// ??PWM???
#define MAX_PWM_CHANNELS 16

// ???????? (????????????)
#define DEFAULT_DUTY_PERCENT  50

// PWM???????
typedef struct {
    TIM_TypeDef* timer;
    uint8_t channel;
    GPIO_TypeDef* gpio_port;
    uint16_t gpio_pin;
} PWM_ChannelMap_t;

// PWM????? - ?????????
static const PWM_ChannelMap_t pwm_channel_map[MAX_PWM_CHANNELS] = {
    // ??1-4:TIM1
    {TIM1, 1, GPIOA, GPIO_Pin_8},   // ??1: TIM1_CH1 -> PA8
    {TIM1, 2, GPIOA, GPIO_Pin_9},   // ??2: TIM1_CH2 -> PA9
    {TIM1, 3, GPIOA, GPIO_Pin_10},  // ??3: TIM1_CH3 -> PA10
    {TIM1, 4, GPIOA, GPIO_Pin_11},  // ??4: TIM1_CH4 -> PA11
    
    // ??5-8:TIM2
    {TIM2, 1, GPIOA, GPIO_Pin_0},   // ??5: TIM2_CH1 -> PA0
    {TIM2, 2, GPIOA, GPIO_Pin_1},   // ??6: TIM2_CH2 -> PA1
    {TIM2, 3, GPIOA, GPIO_Pin_2},   // ??7: TIM2_CH3 -> PA2
    {TIM2, 4, GPIOA, GPIO_Pin_3},   // ??8: TIM2_CH4 -> PA3
    
    // ??9-12:TIM3
    {TIM3, 1, GPIOA, GPIO_Pin_6},   // ??9: TIM3_CH1 -> PA6
    {TIM3, 2, GPIOA, GPIO_Pin_7},   // ??10: TIM3_CH2 -> PA7
    {TIM3, 3, GPIOB, GPIO_Pin_0},   // ??11: TIM3_CH3 -> PB0
    {TIM3, 4, GPIOB, GPIO_Pin_1},   // ??12: TIM3_CH4 -> PB1
    
    // ??13-16:TIM4
    {TIM4, 1, GPIOB, GPIO_Pin_6},   // ??13: TIM4_CH1 -> PB6
    {TIM4, 2, GPIOB, GPIO_Pin_7},   // ??14: TIM4_CH2 -> PB7
    {TIM4, 3, GPIOB, GPIO_Pin_8},   // ??15: TIM4_CH3 -> PB8
    {TIM4, 4, GPIOB, GPIO_Pin_9},   // ??16: TIM4_CH4 -> PB9
};

/**
 * @brief  ?????????
 * @param  TIMx: ?????
 * @retval ????
 */
static uint32_t PWM_GetTimerClock(TIM_TypeDef* TIMx)
{
    if (TIMx == TIM1) {
        return F_CPU_APB2; // TIM1??APB2??
    } else {
        return F_CPU_APB1; // TIM2/3/4??APB1??
    }
}

/**
 * @brief  ???????????PWM??
 * @param  TIMx: ?????
 * @param  freq_hz: ????(Hz)
 * @param  duty_percent: ??????(0-100)
 * @note   ??????PSC?ARR,????<0.1%
 * @retval None
 */
static void PWM_ConfigTimerHighPrecision(TIM_TypeDef* TIMx, uint32_t freq_hz, uint8_t duty_percent)
{
    if (freq_hz == 0) return;
    
    uint32_t timer_clk = PWM_GetTimerClock(TIMx);
    
    // ?? (PSC+1) * (ARR+1) = timer_clk / freq_hz
    uint32_t total = timer_clk / freq_hz;
    
    // ?????PSC?ARR??
    // ??: PSC???,ARR???,??????????
    uint16_t best_psc = 0;
    uint16_t best_arr = 99;  // ???
    uint32_t min_error = 0xFFFFFFFF;
    
    for (uint16_t psc = 0; psc < 100 && psc < total; psc++)
    {
        uint32_t arr = total / (psc + 1) - 1;
        
        // ARR???????? (1 ~ 65535)
        if (arr < 1 || arr > 65535) continue;
        
        // ?????????
        uint32_t actual_freq = timer_clk / ((psc + 1) * (arr + 1));
        uint32_t error = (actual_freq > freq_hz) ? 
                         (actual_freq - freq_hz) : (freq_hz - actual_freq);
        
        if (error < min_error)
        {
            min_error = error;
            best_psc = psc;
            best_arr = (uint16_t)arr;
            
            // ?????0,????
            if (error == 0) break;
        }
    }
    
    // ??CCR? (???)
    uint16_t ccr = (uint16_t)(((uint32_t)best_arr + 1) * duty_percent / 100);
    
    // ?????
    TIM_TimeBaseInitTypeDef TIM_TimeBaseInitStructure;
    TIM_TimeBaseStructInit(&TIM_TimeBaseInitStructure);
    TIM_TimeBaseInitStructure.TIM_Period = best_arr;
    TIM_TimeBaseInitStructure.TIM_Prescaler = best_psc;
    TIM_TimeBaseInitStructure.TIM_ClockDivision = TIM_CKD_DIV1;
    TIM_TimeBaseInitStructure.TIM_CounterMode = TIM_CounterMode_Up;
    TIM_TimeBaseInitStructure.TIM_RepetitionCounter = 0;
    
    TIM_TimeBaseInit(TIMx, &TIM_TimeBaseInitStructure);
    TIM_ARRPreloadConfig(TIMx, ENABLE);
    
    // ???????CCR??????
    TIMx->CCR1 = ccr;
    TIMx->CCR2 = ccr;
    TIMx->CCR3 = ccr;
    TIMx->CCR4 = ccr;
}

/**
 * @brief  ????PWM????
 * @param  TIMx: ?????
 * @param  channel: ???(1-4)
 * @retval None
 */
static void PWM_ConfigChannel(TIM_TypeDef* TIMx, uint8_t channel)
{
    TIM_OCInitTypeDef TIM_OCInitStruct;
    TIM_OCStructInit(&TIM_OCInitStruct);
    TIM_OCInitStruct.TIM_OCMode = TIM_OCMode_PWM1;
    TIM_OCInitStruct.TIM_OutputState = TIM_OutputState_Enable;
    TIM_OCInitStruct.TIM_Pulse = 0; // ?????0%
    TIM_OCInitStruct.TIM_OCPolarity = TIM_OCPolarity_High;
    
    switch(channel) {
        case 1: TIM_OC1Init(TIMx, &TIM_OCInitStruct); TIM_OC1PreloadConfig(TIMx, TIM_OCPreload_Enable); break;
        case 2: TIM_OC2Init(TIMx, &TIM_OCInitStruct); TIM_OC2PreloadConfig(TIMx, TIM_OCPreload_Enable); break;
        case 3: TIM_OC3Init(TIMx, &TIM_OCInitStruct); TIM_OC3PreloadConfig(TIMx, TIM_OCPreload_Enable); break;
        case 4: TIM_OC4Init(TIMx, &TIM_OCInitStruct); TIM_OC4PreloadConfig(TIMx, TIM_OCPreload_Enable); break;
        default: break;
    }
}

/**
 * @brief  ??GPIO???????
 * @param  gpio_port: GPIO??
 * @param  gpio_pin: GPIO??
 * @retval None
 */
static void PWM_ConfigGPIO(GPIO_TypeDef* gpio_port, uint16_t gpio_pin)
{
    GPIO_InitTypeDef GPIO_InitStructure;
    GPIO_InitStructure.GPIO_Pin = gpio_pin;
    GPIO_InitStructure.GPIO_Mode = GPIO_Mode_AF_PP;
    GPIO_InitStructure.GPIO_Speed = GPIO_Speed_50MHz;
    GPIO_Init(gpio_port, &GPIO_InitStructure);
}

/**
 * @brief  ?????PWM??(?16???)
 * @param  initial_freq_hz: ??PWM??(??: Hz)
 * @retval None
 */
void PWM_Init(uint32_t initial_freq_hz)
{
    // 1. ????
    RCC_APB2PeriphClockCmd(RCC_APB2Periph_TIM1 | RCC_APB2Periph_GPIOA | RCC_APB2Periph_GPIOB, ENABLE);
    RCC_APB1PeriphClockCmd(RCC_APB1Periph_TIM2 | RCC_APB1Periph_TIM3 | RCC_APB1Periph_TIM4, ENABLE);

    // 2. ????GPIO??
    for (uint8_t i = 0; i < MAX_PWM_CHANNELS; i++) {
        PWM_ConfigGPIO(pwm_channel_map[i].gpio_port, pwm_channel_map[i].gpio_pin);
    }

    // 3. ????? (???????)
    PWM_ConfigTimerHighPrecision(TIM1, initial_freq_hz, DEFAULT_DUTY_PERCENT);
    PWM_ConfigTimerHighPrecision(TIM2, initial_freq_hz, DEFAULT_DUTY_PERCENT);
    PWM_ConfigTimerHighPrecision(TIM3, initial_freq_hz, DEFAULT_DUTY_PERCENT);
    PWM_ConfigTimerHighPrecision(TIM4, initial_freq_hz, DEFAULT_DUTY_PERCENT);
    
    // 4. ??PWM????
    for (uint8_t ch = 1; ch <= 4; ch++) {
        PWM_ConfigChannel(TIM1, ch);
        PWM_ConfigChannel(TIM2, ch);
        PWM_ConfigChannel(TIM3, ch);
        PWM_ConfigChannel(TIM4, ch);
    }
    
    // 5. ????????????(TIM1??????)
    TIM_CtrlPWMOutputs(TIM1, ENABLE);
    
    // 6. ?????
    TIM_Cmd(TIM1, ENABLE);
    TIM_Cmd(TIM2, ENABLE);
    TIM_Cmd(TIM3, ENABLE);
    TIM_Cmd(TIM4, ENABLE);
}

/**
 * @brief  ???????????PWM?? (??????????)
 * @param  TIMx: ?????
 * @param  freq_hz: ????(Hz)
 * @note   ????<0.1%,????50%???
 * @retval None
 */
void PWM_SetFrequency(TIM_TypeDef* TIMx, uint32_t freq_hz)
{
    if (freq_hz == 0) return;
    
    uint32_t timer_clk = PWM_GetTimerClock(TIMx);
    
    // ?? (PSC+1) * (ARR+1) = timer_clk / freq_hz
    uint32_t total = timer_clk / freq_hz;
    
    // ?????PSC?ARR??
    uint16_t best_psc = 0;
    uint16_t best_arr = 99;
    uint32_t min_error = 0xFFFFFFFF;
    
    for (uint16_t psc = 0; psc < 100 && psc < total; psc++)
    {
        uint32_t arr = total / (psc + 1) - 1;
        
        if (arr < 1 || arr > 65535) continue;
        
        uint32_t actual_freq = timer_clk / ((psc + 1) * (arr + 1));
        uint32_t error = (actual_freq > freq_hz) ? 
                         (actual_freq - freq_hz) : (freq_hz - actual_freq);
        
        if (error < min_error)
        {
            min_error = error;
            best_psc = psc;
            best_arr = (uint16_t)arr;
            
            if (error == 0) break;
        }
    }
    
    // ????CCR? (??50%???)
    uint16_t ccr = (best_arr + 1) / 2;
    
    // ?????
    TIMx->PSC = best_psc;
    TIMx->ARR = best_arr;
    TIMx->CCR1 = ccr;
    TIMx->CCR2 = ccr;
    TIMx->CCR3 = ccr;
    TIMx->CCR4 = ccr;
    
    // ??????,??????
    TIMx->EGR = TIM_EGR_UG;
}

/**
 * @brief  ????????PWM??
 * @param  freq_hz: ????(Hz)
 * @retval None
 */
void PWM_SetFrequencyAll(uint32_t freq_hz)
{
    PWM_SetFrequency(TIM1, freq_hz);
    PWM_SetFrequency(TIM2, freq_hz);
    PWM_SetFrequency(TIM3, freq_hz);
    PWM_SetFrequency(TIM4, freq_hz);
}

/**
 * @brief  ??????????????? (???)
 * @param  TIMx: ?????
 * @param  channel: ???(1-4)
 * @param  duty_percent: ???(0-100)
 * @retval None
 */
void PWM_SetDutyPercent(TIM_TypeDef* TIMx, uint8_t channel, uint8_t duty_percent)
{
    if (duty_percent > 100) duty_percent = 100;
    
    uint16_t arr = TIMx->ARR;
    uint16_t ccr = (uint16_t)(((uint32_t)arr + 1) * duty_percent / 100);
    
    switch (channel)
    {
        case 1: TIMx->CCR1 = ccr; break;
        case 2: TIMx->CCR2 = ccr; break;
        case 3: TIMx->CCR3 = ccr; break;
        case 4: TIMx->CCR4 = ccr; break;
    }
}

/**
 * @brief  ???????PWM??? (?????)
 * @param  channel: ???(1-16)
 * @param  duty_percent: ???(0-100)
 * @retval 0: ??, -1: ????
 */
int8_t PWM_SetDutyCycle(uint8_t channel, uint16_t duty_percent)
{
    if (channel == 0 || channel > MAX_PWM_CHANNELS || duty_percent > 100) {
        return -1;
    }
    
    const PWM_ChannelMap_t* map = &pwm_channel_map[channel - 1];
    PWM_SetDutyPercent(map->timer, map->channel, (uint8_t)duty_percent);
    
    return 0;
}

/**
 * @brief  ???????PWM???
 * @param  duty_percent: ???(0-100)
 * @retval None
 */
void PWM_SetDutyCycleAll(uint16_t duty_percent)
{
    if (duty_percent > 100) duty_percent = 100;
    
    for (uint8_t i = 1; i <= MAX_PWM_CHANNELS; i++) {
        PWM_SetDutyCycle(i, duty_percent);
    }
}

/**
 * @brief  ??/????PWM??
 * @param  channel: ???(1-16)
 * @param  enable: ENABLE?DISABLE
 * @retval 0: ??, -1: ????
 */
int8_t PWM_EnableChannel(uint8_t channel, FunctionalState enable)
{
    if (channel == 0 || channel > MAX_PWM_CHANNELS) {
        return -1;
    }
    
    const PWM_ChannelMap_t* map = &pwm_channel_map[channel - 1];
    
    switch(map->channel) {
			
			
			
			
			
			
			
			
			
			
			
			
			
			
			
			
			
			
			
			
			
			
			
			
			
			
			
			
			
			
			
			
			
			
        case 1: TIM_CCxCmd(map->timer, TIM_Channel_1, enable); break;
        case 2: TIM_CCxCmd(map->timer, TIM_Channel_2, enable); break;
        case 3: TIM_CCxCmd(map->timer, TIM_Channel_3, enable); break;
        case 4: TIM_CCxCmd(map->timer, TIM_Channel_4, enable); break;
        default: return -1;
    }
    
    return 0;
}

/**
 * @brief  ????????????
 * @param  channel: ???(1-16)
 * @retval ??????(0-100), 0xFFFF??????
 */
uint16_t PWM_GetDutyCycle(uint8_t channel)
{
    if (channel == 0 || channel > MAX_PWM_CHANNELS) {
        return 0xFFFF;
    }
    
    const PWM_ChannelMap_t* map = &pwm_channel_map[channel - 1];
    uint16_t arr = map->timer->ARR;
    uint16_t ccr = 0;
    
    switch(map->channel) {
        case 1: ccr = TIM_GetCapture1(map->timer); break;
        case 2: ccr = TIM_GetCapture2(map->timer); break;
        case 3: ccr = TIM_GetCapture3(map->timer); break;
        case 4: ccr = TIM_GetCapture4(map->timer); break;
        default: return 0xFFFF;
    }
    
    // ?????
    return (uint16_t)((uint32_t)ccr * 100 / (arr + 1));
}

/**
 * @brief  ?????????????
 * @param  TIMx: ?????
 * @retval ????(Hz)
 */
uint32_t PWM_GetActualFrequency(TIM_TypeDef* TIMx)
{
    uint32_t timer_clk = PWM_GetTimerClock(TIMx);
    uint16_t psc = TIMx->PSC;
    uint16_t arr = TIMx->ARR;
    
    return timer_clk / ((psc + 1) * (arr + 1));
}

// ?????
void PWM_SetCompare(uint16_t Compare)
{
    PWM_SetDutyCycleAll(Compare);
}