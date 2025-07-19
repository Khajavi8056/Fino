//+------------------------------------------------------------------+
//| FiboTestExpert.mq5                                               |
//| اکسپرت ساده برای تست کتابخانه FibonacciEngine                   |
//| فقط فیبوناچی‌ها را بر اساس سقف‌ها و کف‌های شناسایی‌شده رسم می‌کند |
//| نسخه: 1.01                                                      |
//| تاریخ: 2025-07-20                                              |
//+------------------------------------------------------------------+

#property copyright "Your Name"
#property version   "1.01"
#property strict

//--- شامل کتابخانه
#include "FibonacciEngine.mqh"

//--- شیء کتابخانه
CFibonacciEngine fiboEngine;

//+------------------------------------------------------------------+
//| تابع مقداردهی اولیه اکسپرت                                    |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- مقداردهی اولیه کتابخانه
   if(!fiboEngine.Init())
   {
      Print("خطا در مقداردهی اولیه FibonacciEngine");
      return(INIT_FAILED);
   }
   Print("FibonacciEngine با موفقیت مقداردهی اولیه شد");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| تابع اصلی اکسپرت                                              |
//+------------------------------------------------------------------+
void OnTick()
{
   //--- بررسی کندل جدید
   static datetime lastCandleTime = 0;
   datetime currentTime = iTime(_Symbol, _Period, 0);
   if(currentTime != lastCandleTime)
   {
      lastCandleTime = currentTime;
      
      //--- شناسایی ساختارها
      fiboEngine.ScoutForStructure();
      
      //--- بررسی وضعیت و رسم فیبوناچی
      ENUM_FIBO_STATUS status = fiboEngine.GetFiboStatus();
      if(status == STATUS_WAITING)
      {
         //--- امتحان برای جهت صعودی
         if(fiboEngine.AnalyzeAndDrawFibo(true))
         {
            Print("فیبوناچی صعودی رسم شد");
         }
         //--- امتحان برای جهت نزولی
         if(fiboEngine.AnalyzeAndDrawFibo(false))
         {
            Print("فیبوناچی نزولی رسم شد");
         }
      }
      
      //--- بررسی شرایط (نگهبانی)
      fiboEngine.CheckConditions();
   }
}

//+------------------------------------------------------------------+
//| تابع دفع‌کننده اکسپرت                                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Print("اکسپرت تست FibonacciEngine غیرفعال شد. دلیل: ", reason);
}
//+------------------------------------------------------------------+
