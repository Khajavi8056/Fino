//+------------------------------------------------------------------+
//|                                           HipoFibonacciTestEA.mq5 |
//|                              محصولی از: Hipo Algorithm           |
//|                              نسخه: ۱.۵                            |
//|                              تاریخ: ۲۰۲۵/۰۷/۲۳                   |
//| اکسپرت ساده برای اجرای حالت تست دستی کتابخانه HipoFibonacci   |
//+------------------------------------------------------------------+

#property copyright "Hipo Algorithm"
#property link      "https://hipoalgorithm.com"
#property version   "1.5"

#include <HipoFibonacci.mqh>

//+------------------------------------------------------------------+
//| Expert initialization function                                     |
//+------------------------------------------------------------------+
int OnInit()
{
   if(!InpTestMode)
   {
      Print("خطا: حالت تست (InpTestMode) باید فعال باشد");
      return(INIT_PARAMETERS_INCORRECT);
   }

   g_manager = new CStructureManager();
   if(g_manager == NULL)
   {
      Print("خطا: نمی‌توان CStructureManager را ایجاد کرد");
      return(INIT_FAILED);
   }

   if(!g_manager.HFiboOnInit())
   {
      delete g_manager;
      g_manager = NULL;
      Print("خطا: راه‌اندازی کتابخانه HipoFibonacci نامو
