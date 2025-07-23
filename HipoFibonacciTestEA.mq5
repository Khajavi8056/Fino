//+------------------------------------------------------------------+
//|                                           HipoFibonacciTestEA.mq5 |
//|                              محصولی از: Hipo Algorithm           |
//|                              نسخه: ۱.۴                            |
//|                              تاریخ: ۲۰۲۵/۰۷/۲۳                   |
//| اکسپرت ساده برای اجرای حالت تست دستی کتابخانه HipoFibonacci   |
//+------------------------------------------------------------------+

#property copyright "Hipo Algorithm"
#property link      "https://hipoalgorithm.com"
#property version   "1.4"

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

   EventSetTimer(1); // تایمر را روی هر 1 ثانیه تنظیم کن
   Print("اکسپرت HipoFibonacciTestEA شروع شد. حالت تست دستی فعال است.");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                   |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer(); // تایمر را متوقف کن
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
//| Expert timer function                                             |
//+------------------------------------------------------------------+
void OnTimer()
{
   static datetime last_bar_time = 0;
   datetime current_bar_time = (datetime)SeriesInfoInteger(_Symbol, _Period, SERIES_LASTBAR_DATE);

   if(current_bar_time > last_bar_time)
   {
      last_bar_time = current_bar_time;
      if(g_manager != NULL)
         g_manager.HFiboOnNewBar();
   }
}

//+------------------------------------------------------------------+
//| Expert chart event function                                       |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   Print("اکسپرت تست: رویداد چارت دریافت شد! ID=", id, ", sparam=", sparam);
   if(g_manager != NULL)
      g_manager.HFiboOnChartEvent(id, lparam, dparam, sparam);
}

//+------------------------------------------------------------------+
