//+------------------------------------------------------------------+
//|                                           HipoFibonacciTestEA.mq5 |
//|                              محصولی از: Hipo Algorithm           |
//|                              نسخه: ۱.۰                            |
//|                              تاریخ: ۲۰۲۵/۰۷/۲۳                   |
//| اکسپرت ساده برای اجرای حالت تست دستی کتابخانه HipoFibonacci   |
//+------------------------------------------------------------------+

#property copyright "Hipo Algorithm"
#property link      "https://hipoalgorithm.com"
#property version   "1.0"

#include <HipoFibonacci.mqh>

//+------------------------------------------------------------------+
//| Expert initialization function                                     |
//+------------------------------------------------------------------+
int OnInit()
{
   // فراخوانی تابع OnInit از کتابخانه
   ::OnInit();
   Print("اکسپرت HipoFibonacciTestEA شروع شد. حالت تست دستی فعال است.");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                   |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // فراخوانی تابع OnDeinit از کتابخانه
   ::OnDeinit(reason);
   Print("اکسپرت HipoFibonacciTestEA متوقف شد. دلیل: ", reason);
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
{
   // فراخوانی تابع OnTick از کتابخانه
   ::OnTick();
}

//+------------------------------------------------------------------+
//| Expert chart event function                                       |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   // فراخوانی تابع OnChartEvent از کتابخانه برای مدیریت کلیک‌های پنل
   ::OnChartEvent(id, lparam, dparam, sparam);
}

//+------------------------------------------------------------------+
//| Expert new bar function                                           |
//+------------------------------------------------------------------+
void OnTimer()
{
   // فراخوانی تابع OnNewBar از کتابخانه برای مدیریت بارهای جدید
   ::OnNewBar();
}

//+------------------------------------------------------------------+
