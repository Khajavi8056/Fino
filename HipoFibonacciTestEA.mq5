//+------------------------------------------------------------------+
//|                                           HipoFibonacciTestEA.mq5 |
//|                              محصولی از: Hipo Algorithm           |
//|                              نسخه: ۱.۱                            |
//|                              تاریخ: ۲۰۲۵/۰۷/۲۳                   |
//| اکسپرت ساده برای اجرای حالت تست دستی کتابخانه HipoFibonacci   |
//+------------------------------------------------------------------+

#property copyright "Hipo Algorithm"
#property link      "https://hipoalgorithm.com"
#property version   "1.1"

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
      Print("خطا: راه‌اندازی کتابخانه HipoFibonacci ناموفق بود");
      return(INIT_FAILED);
   }

   Print("اکسپرت HipoFibonacciTestEA شروع شد. حالت تست دستی فعال است.");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                   |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(g_manager != NULL)
   {
      g_manager.HFiboOnDeinit(reason);
      delete g_manager;
      g_manager = NULL;
   }
   Print("اکسپرت HipoFibonacciTestEA متوقف شد. دلیل: ", reason);
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
{
   if(g_manager != NULL)
      g_manager.HFiboOnTick();
}

//+------------------------------------------------------------------+
//| Expert chart event function                                       |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   if(g_manager != NULL)
      g_manager.HFiboOnChartEvent(id, lparam, dparam, sparam);
}

//+------------------------------------------------------------------+
//| Expert timer function                                             |
//+------------------------------------------------------------------+
void OnTimer()
{
   if(g_manager != NULL)
      g_manager.HFiboOnNewBar();
}

//+------------------------------------------------------------------+
