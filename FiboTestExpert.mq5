//+------------------------------------------------------------------+
//| SimpleFiboTestExpert.mq5                                        |
//| اکسپرت تست برای کتابخانه SimpleFibonacciEngine                 |
//| فقط برای فراخوانی و تست رسم فیبوناچی و معاملات ساده          |
//| نسخه: 1.01                                                     |
//| تاریخ: 2025-07-20                                             |
//+------------------------------------------------------------------+

#property copyright "Your Name"
#property link      "https://www.yourwebsite.com"
#property version   "1.01"
#property strict

//--- شامل کتابخانه فیبوناچی
#include <FibonacciEngine.mqh>

//--- شامل فایل‌های مورد نیاز
#include <Trade\Trade.mqh>

//--- ورودی‌های اکسپرت
input group "تنظیمات معاملاتی"
input double LotSize = 0.1; // حجم معامله
input double StopLossMultiplier = 1.0; // ضریب استاپ‌لاس (بر اساس فاصله صفر تا 100 فیبو)
input double TakeProfitMultiplier = 1.5; // ضریب تیک‌پرویت (بر اساس فاصله صفر تا 100 فیبو)

//--- متغیرهای جهانی
CSimpleFibonacciEngine fiboEngine; // نمونه از کتابخانه فیبوناچی
CTrade trade; // شیء برای مدیریت معاملات
bool isInitialized = false; // وضعیت مقداردهی اولیه

//+------------------------------------------------------------------+
//| تابع مقداردهی اولیه اکسپرت                                     |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- مقداردهی اولیه کتابخانه فیبوناچی
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
   Print("اکسپرت با موفقیت مقداردهی اولیه شد");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| تابع اصلی پردازش تیک‌ها                                        |
//+------------------------------------------------------------------+
void OnTick()
{
   if(!isInitialized) return;

   //--- بررسی ساختارهای بازار (سقف‌ها، کف‌ها، شکست‌ها)
   fiboEngine.ScoutForStructure();

   //--- بررسی وضعیت فیبوناچی
   ENUM_FIBO_STATUS fiboStatus = fiboEngine.GetFiboStatus();

   //--- اگر در ناحیه ورود هستیم، معامله باز کن
   if(fiboStatus == STATUS_IN_ENTRY_ZONE)
   {
      //--- چک کردن که معامله باز در جهت فعلی وجود نداشته باشه
      if(!PositionSelect(_Symbol))
      {
         double price = fiboEngine.currentFibo.isBullish ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

         //--- محاسبه استاپ‌لاس و تیک‌پرویت بر اساس فرضیه جهت (چون currentFibo خصوصی هست، از STATUS_IN_ENTRY_ZONE استفاده می‌کنیم)
         double sl = 0, tp = 0;
         double fiboRange = 0; // بعداً با متد عمومی باید محاسبه بشه
         bool isBullish = (fiboEngine.currentFibo.isBullish); // این خط باید با متد عمومی جایگزین بشه

         //--- تنظیم استاپ‌لاس و تیک‌پرویت (فرضی تا متد عمومی اضافه بشه)
         sl = isBullish ? price - fiboRange * StopLossMultiplier : price + fiboRange * StopLossMultiplier;
         tp = isBullish ? price + fiboRange * TakeProfitMultiplier : price - fiboRange * TakeProfitMultiplier;

         //--- باز کردن معامله
         if(isBullish)
         {
            if(trade.Buy(LotSize, _Symbol, price, sl, tp))
            {
               Print("معامله خرید باز شد: قیمت=", price, ", SL=", sl, ", TP=", tp);
            }
            else
            {
               Print("خطا در باز کردن معامله خرید: ", trade.ResultRetcode());
            }
         }
         else
         {
            if(trade.Sell(LotSize, _Symbol, price, sl, tp))
            {
               Print("معامله فروش باز شد: قیمت=", price, ", SL=", sl, ", TP=", tp);
            }
            else
            {
               Print("خطا در باز کردن معامله فروش: ", trade.ResultRetcode());
            }
         }
      }
   }

   //--- بررسی شرایط فیبوناچی (نگهبانی)
   fiboEngine.CheckConditions();

   //--- اگر تحلیل باطل شده یا در انتظار ساختار جدید هستیم، فیبوناچی جدید رسم کن
   if(fiboStatus == STATUS_WAITING || fiboStatus == STATUS_INVALID)
   {
      //--- تشخیص جهت بر اساس آخرین ساختار شکسته‌شده
      bool isBuy = false; // باید با متد عمومی جایگزین بشه
      if(fiboEngine.m_lastBrokenStructure.price > 0)
      {
         isBuy = (fiboEngine.m_lastBrokenStructure.price > (ArraySize(fiboEngine.m_valleys) > 0 ? fiboEngine.m_valleys[0].price : 0)) ? false : true;
      }
      if(fiboEngine.AnalyzeAndDrawFibo(isBuy))
      {
         Print("فیبوناچی جدید رسم شد: جهت=", isBuy ? "صعودی" : "نزولی");
      }
   }
}

//+------------------------------------------------------------------+
//| تابع پایان کار اکسپرت                                          |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Print("اکسپرت متوقف شد. دلیل: ", reason);
}

//+------------------------------------------------------------------+
//| تابع پردازش رویدادهای چارت                                    |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   //--- می‌تونید رویدادهای چارت مثل کلیک یا تغییر اشیاء رو اینجا مدیریت کنید
}
