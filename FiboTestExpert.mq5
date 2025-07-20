//+------------------------------------------------------------------+
//| FibonacciTestExpert.mq5                                          |
//| اکسپرت تست برای کتابخانه SimpleFibonacciEngine                 |
//| نسخه: 1.00                                                     |
//| تاریخ: 2025-07-20                                             |
//+------------------------------------------------------------------+

#property copyright "Your Name"
#property link      "https://www.yourwebsite.com"
#property version   "1.00"
#property strict

//--- شامل کتابخانه فیبوناچی
#include <SimpleFibonacciEngine.mqh>

//--- ورودی‌های اکسپرت
input group "تنظیمات عمومی"
input double LotSize = 0.1; // حجم معامله
input int StopLossPoints = 100; // استاپ لاس (به نقاط)
input int TakeProfitPoints = 200; // تیک پرافیت (به نقاط)
input bool EnableLogging = true; // فعال‌سازی لاگ‌ها

input group "تنظیمات فیبوناچی"
input ENUM_TIMEFRAMES TF = PERIOD_M5; // تایم‌فریم فیبوناچی
input bool EnforceStrictSequence = true; // اعمال توالی اجباری سقف/کف
input E_DetectionMethod DetectionMethod = METHOD_POWER_SWING; // روش تشخیص Fineflow
input int Lookback = 3; // تعداد کندل‌ها برای نگاه به عقب و جلو
input int MaxScanDepth = 50; // حداکثر کندل‌ها برای اسکن اولیه
input int MaxArraySize = 20; // حداکثر اندازه آرایه‌های سقف و کف
input int SequentialLookback = 2; // تعداد کندل‌ها برای روش پلکانی
input bool UseStrictSequential = true; // حالت سخت‌گیرانه پلکانی
input E_SequentialCriterion SequentialCriterion = CRITERION_HIGH; // معیار پلکانی
input int AtrPeriod = 14; // دوره ATR
input double AtrMultiplier = 2.5; // ضریب ATR
input int ZigZagDepth = 12; // عمق زیگزاگ
input double ZigZagDeviation = 5; // انحراف زیگزاگ
input ENUM_BREAK_TYPE BreakType = BREAK_CONFIRMED; // نوع شکست
input int ConfirmationCandles = 5; // تعداد کندل‌های تأیید برای شکست
input double FiboEntryZoneMin = 50.0; // حداقل درصد ناحیه ورود (50%)
input double FiboEntryZoneMax = 68.0; // حداکثر درصد ناحیه ورود (68%)

//--- متغیرهای جهانی
CSimpleFibonacciEngine fiboEngine; // نمونه از کتابخانه فیبوناچی
CTrade trade; // شیء برای مدیریت معاملات
bool isInitialized = false; // وضعیت مقداردهی اولیه

//+------------------------------------------------------------------+
//| تابع مقداردهی اولیه اکسپرت                                     |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- تنظیم پارامترهای کتابخانه فیبوناچی
   fiboEngine.EnforceStrictSequence = EnforceStrictSequence;
   fiboEngine.TF = TF;
   fiboEngine.Lookback = Lookback;
   fiboEngine.MaxScanDepth = MaxScanDepth;
   fiboEngine.MaxArraySize = MaxArraySize;
   fiboEngine.EnableLogging = EnableLogging;
   fiboEngine.DetectionMethod = DetectionMethod;
   fiboEngine.SequentialLookback = SequentialLookback;
   fiboEngine.UseStrictSequential = UseStrictSequential;
   fiboEngine.SequentialCriterion = SequentialCriterion;
   fiboEngine.AtrPeriod = AtrPeriod;
   fiboEngine.AtrMultiplier = AtrMultiplier;
   fiboEngine.ZigZagDepth = ZigZagDepth;
   fiboEngine.ZigZagDeviation = ZigZagDeviation;
   fiboEngine.BreakType = BreakType;
   fiboEngine.ConfirmationCandles = ConfirmationCandles;
   fiboEngine.FiboEntryZoneMin = FiboEntryZoneMin;
   fiboEngine.FiboEntryZoneMax = FiboEntryZoneMax;

   //--- مقداردهی اولیه کتابخانه
   if(!fiboEngine.Init())
   {
      Print("خطا در مقداردهی اولیه کتابخانه فیبوناچی");
      return(INIT_FAILED);
   }

   //--- تنظیم شیء معاملات
   trade.SetExpertMagicNumber(123456);
   trade.SetDeviationInPoints(10);
   trade.SetTypeFilling(ORDER_FILLING_IOC);

   isInitialized = true;
   if(EnableLogging) Print("اکسپرت با موفقیت مقداردهی اولیه شد");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| تابع اصلی پردازش تیک‌ها                                        |
//+------------------------------------------------------------------+
void OnTick()
{
   if(!isInitialized) return;

   //--- بررسی ساختارهای بازار
   fiboEngine.ScoutForStructure();

   //--- بررسی وضعیت فیبوناچی
   ENUM_FIBO_STATUS fiboStatus = fiboEngine.GetFiboStatus();

   //--- اگر در ناحیه ورود هستیم، معامله باز کن
   if(fiboStatus == STATUS_IN_ENTRY_ZONE)
   {
      //--- بررسی جهت فیبوناچی
      bool isBullish = fiboEngine.currentFibo.isBullish;

      //--- چک کردن اینکه معامله باز در جهت فعلی وجود نداشته باشه
      if(!PositionSelect(_Symbol))
      {
         double sl = 0, tp = 0;
         double price = isBullish ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

         //--- تنظیم استاپ‌لاس و تیک‌پرویت
         if(isBullish)
         {
            sl = price - StopLossPoints * point;
            tp = price + TakeProfitPoints * point;
            if(trade.Buy(LotSize, _Symbol, price, sl, tp))
            {
               if(EnableLogging) Print("معامله خرید باز شد: قیمت=", price, ", SL=", sl, ", TP=", tp);
            }
            else
            {
               if(EnableLogging) Print("خطا در باز کردن معامله خرید: ", trade.ResultRetcode());
            }
         }
         else
         {
            sl = price + StopLossPoints * point;
            tp = price - TakeProfitPoints * point;
            if(trade.Sell(LotSize, _Symbol, price, sl, tp))
            {
               if(EnableLogging) Print("معامله فروش باز شد: قیمت=", price, ", SL=", sl, ", TP=", tp);
            }
            else
            {
               if(EnableLogging) Print("خطا در باز کردن معامله فروش: ", trade.ResultRetcode());
            }
         }
      }
   }

   //--- بررسی شرایط فیبوناچی (نگهبانی)
   fiboEngine.CheckConditions();

   //--- اگر تحلیل باطل شده، بررسی برای رسم فیبوناچی جدید
   if(fiboStatus == STATUS_WAITING || fiboStatus == STATUS_INVALID)
   {
      bool isBuy = (fiboEngine.m_lastBrokenStructure.price > (ArraySize(fiboEngine.m_valleys) > 0 ? fiboEngine.m_valleys[0].price : 0)) ? false : true;
      if(fiboEngine.AnalyzeAndDrawFibo(isBuy))
      {
         if(EnableLogging) Print("فیبوناچی جدید رسم شد: جهت=", isBuy ? "صعودی" : "نزولی");
      }
   }
}

//+------------------------------------------------------------------+
//| تابع پایان کار اکسپرت                                          |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(EnableLogging) Print("اکسپرت متوقف شد. دلیل: ", reason);
}

//+------------------------------------------------------------------+
//| تابع پردازش رویدادهای چارت                                    |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   //--- می‌تونید رویدادهای چارت مثل کلیک یا تغییر اشیاء رو اینجا مدیریت کنید
}
