//+------------------------------------------------------------------+
//|                                           HipoFibonacciTestEA.mq5 |
//|                              محصولی از: Hipo Algorithm             |
//|                              نسخه: ۱.۵                             |
//|                              تاریخ: ۲۰۲۵/۰۷/۲۳                      |
//| اکسپرت ساده برای اجرای حالت تست دستی کتابخانه HipoFibonacci                 |
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
      Print("خطا: راه‌اندازی کتابخانه HipoFibonacci ناموفق بود");
      return(INIT_FAILED);
   }

   EventSetTimer(1); // تنظیم تایمر برای اطمینان از آپدیت‌های منظم
   Print("اکسپرت تست HipoFibonacci راه‌اندازی شد");
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
   EventKillTimer();
   Print("اکسپرت تست HipoFibonacci متوقف شد. دلیل: ", reason);
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
   if(g_manager != NULL)
   {
      g_manager.HFiboOnTick(); // اطمینان از آپدیت در بازارهای کم‌حرکت
      if(iTime(_Symbol, _Period, 0) != iTime(_Symbol, _Period, 1))
         g_manager.HFiboOnNewBar();
   }
}

//+------------------------------------------------------------------+
//| Expert chart event function                                       |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   if(g_manager != NULL)
   {
      g_manager.HFiboOnChartEvent(id, lparam, dparam, sparam);
      Print("اکسپرت تست: رویداد چارت دریافت شد! ID=", id, ", sparam=", sparam, ", زمان=", TimeToString(TimeCurrent()));
   }
}

//+------------------------------------------------------------------+
