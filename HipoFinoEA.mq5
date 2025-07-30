//+------------------------------------------------------------------+
//|                                                  HipoFinoExpert.mq5 |
//|                              محصولی از: Hipo Algorithm           |
//|                              نسخه: ۱.۱.۰                          |
//|                              تاریخ: ۲۰۲۵/۰۷/۲۵                   |
//+------------------------------------------------------------------+

#property copyright "Hipo Algorithm"
#property link      "https://hipoalgorithm.com"
#property version   "1.1.0"

//+------------------------------------------------------------------+
//| شامل کردن کتابخانه‌ها                                           |
//+------------------------------------------------------------------+
#include <Trade\Trade.mqh>
#include <HipoFibonacci.mqh>
#include "HipoFino.mqh"
#include "HipoDashboard.mqh"
#include "HipoMomentumFractals.mqh"
#include "HipoCvtChannel.mqh"
#include "HipoInitialStopLoss.mqh" 
//+------------------------------------------------------------------+
//|ENUMs            |
//+------------------------------------------------------------------+

  



//+------------------------------------------------------------------+
//| ورودی‌های اکسپرت (نسخه بازنویسی شده با گروه‌بندی جدید)            |
//+------------------------------------------------------------------+
input group "تنظیمات عمومی"
input bool InpShowPanel = true;           // نمایش پنل گرافیکی
/*input*/ bool InpShowMacd = false;            // نمایش اندیکاتورهای مکدی
input ENUM_TIMEFRAMES InpHTF = PERIOD_H1; // تایم‌فریم مکدی روند (HTF)
input ENUM_TIMEFRAMES InpLTF = PERIOD_M5; // تایم‌فریم مکدی تریگر (LTF)
input double InpRiskPercent = 1.0;        // درصد ریسک از موجودی (0.1-10.0)
input int InpSLBufferPips = 10;           // بافر حد ضرر (پیپ)
input long InpMagicNumber = 123456;       // شماره جادویی (Magic Number)

input group " HTF (روند)"
input int InpHTFFastEMA = 48;             // دوره سریع EMA
input int InpHTFSlowEMA = 104;            // دوره کند EMA
input int InpHTFSignal = 36;              // دوره سیگنال

input group "  LTF (تریگر)"
input int InpLTFFastEMA = 6;              // دوره سریع EMA
input int InpLTFSlowEMA = 13;             // دوره کند EMA
input int InpLTFSignal = 5;               // دوره سیگنال

input group "فیلتر سشن معاملاتی"
input bool InpUseSessionFilter = false;        // >>> فعال‌سازی فیلتر سشن
input bool InpTokyoSession = true;            // فعال کردن سشن توکیو
input bool InpLondonSession = true;           // فعال کردن سشن لندن
input bool InpNewYorkSession = true;          // فعال کردن سشن نیویورک
input string InpCustomSessionStart = "00:00"; // ساعت شروع سشن سفارشی (HH:MM)
input string InpCustomSessionEnd = "23:59";   // ساعت پایان سشن سفارشی (HH:MM)

// --- گروه جدید برای خروج پله‌ای ---
input group "مدیریت خروج پله‌ای (Partial TP)"
input bool InpUsePartialTP = true;             // >>> فعال‌سازی خروج پله‌ای
input string InpPartialTP_Percentages = "33, 33, 34"; // درصدهای حجم برای ۳ پله خروج (با کاما جدا شود)
input double InpFixedTP_RR = 2.0;              // نسبت ریسک به ریوارد (برای حالت خروج یکجا)

// --- گروه جدید برای تریلینگ استاپ ---
input group "مدیریت حد ضرر متحرک (Trailing Stop)"
input bool InpUseTrailingStop = true;          // >>> فعال‌سازی تریلینگ استاپ
input double InpTrailingActivationRR = 1.5;    // نسبت ریوارد برای فعال‌سازی تریلینگ
input ENUM_STOP_METHOD InpStopMethod = STOP_CVT; // روش تریلینگ استاپ
input bool InpShowStopLine = true;             // نمایش خط استاپ
input group "   تنظیمات روش SAR"
input double InpSarStep = 0.02;                // گام SAR
input double InpSarMaximum = 0.2;              // حداکثر SAR
input group "   تنظیمات روش CVT Channel"
input int InpMinLookback = 5;                  // حداقل دوره کانال CVT
input int InpMaxLookback = 20;                 // حداکثر دوره کانال CVT
input group "   تنظیمات روش Fractal"
input bool InpShowFractals = true;             // نمایش فراکتال‌ها (برای حالت بصری)
input int InpFractalBars = 3;                  // تعداد کندل‌های فراکتال
input int InpFractalBufferPips = 5;            // بافر فراکتال (پیپ)

input group "مدیریت حد ضرر اولیه (Initial Stop Loss)" // 👈 گروه جدید
input ENUM_INITIAL_STOP_METHOD InpInitialStopMethod = INITIAL_STOP_MOTHER_ZERO; // 👈 ورودی انتخاب روش[span_1](end_span)
input int InpInitialSLBufferPips = 10; // 👈 بافر پیپ عمومی برای استاپ اولیه[span_2](end_span)
input group "فیلتر ورود با مووینگ اوریج"
input bool InpUseMAEntryFilter = false;          // >>> فعال سازی فیلتر ورود با MA
input int InpMAFilterPeriod = 5;                 // دوره مووینگ اوریج فیلتر
input ENUM_MA_METHOD InpMAFilterMethod = MODE_EMA; // نوع مووینگ اوریج فیلتر
input ENUM_APPLIED_PRICE InpMAFilterPrice = PRICE_CLOSE; // قیمت اعمالی مووینگ اوریج فیلتر
input group "   تنظیمات روش ATR و میانگین متحرک"
input ENUM_TIMEFRAMES InpATRMATimeframe = PERIOD_H1; // 👈 تایم‌فریم ATR/MA[span_3](end_span)
input ENUM_MA_METHOD InpMAMethod = MODE_EMA;         // 👈 نوع میانگین متحرک (EMA/SMA)
input int InpMAPeriod = 50;                          // 👈 دوره میانگین متحرک
input ENUM_APPLIED_PRICE InpMAPrice = PRICE_CLOSE;   // 👈 قیمت اعمالی برای میانگین متحرک
input int InpATRPeriod = 14;                         // 👈 دوره ATR
input double InpATRMultiplier = 1.5;                 // 👈 ضریب ATR

input group "   تنظیمات روش فراکتال ساده"
input ENUM_TIMEFRAMES InpSimpleFractalTimeframe = PERIOD_M15; // 👈 تایم‌فریم فراکتال ساده
input int InpSimpleFractalBars = 20;                 // 👈 تعداد کندل برای جستجوی فراکتال ساده (N)
input int InpSimpleFractalPeers = 2;                 // 👈 تعداد کندل‌های چپ/راست برای تعریف فراکتال
input double InpSimpleFractalBufferPips = 3;         // 👈 بافر پیپ برای فراکتال ساده


//+------------------------------------------------------------------+
//| متغیرهای سراسری                                                |
//+------------------------------------------------------------------+
CHipoFino* g_engine = NULL;  // نمونه موتور اصلی
CHipoDashboard* g_dashboard = NULL;  // نمونه داشبورد گرافیکی
datetime g_last_tick_time = 0;  // زمان آخرین تیک برای محدود کردن فرکانس

//+------------------------------------------------------------------+
//| تابع اعتبارسنجی زمان سشن سفارشی                               |
//+------------------------------------------------------------------+
bool ValidateCustomSessionTime(string time_str)
{
   string parts[];
   if(StringSplit(time_str, ':', parts) != 2) return false;
   int hour = (int)StringToInteger(parts[0]);
   int minute = (int)StringToInteger(parts[1]);
   return (hour >= 0 && hour <= 23 && minute >= 0 && minute <= 59);
}

//+------------------------------------------------------------------+
//| تابع راه‌اندازی اکسپرت                                         |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| تابع راه‌اندازی اکسپرت                                         |
//+------------------------------------------------------------------+
int OnInit()
{
   // غیرفعال کردن گرید چارت
   ChartSetInteger(0, CHART_SHOW_GRID, false);
   
   // تنظیم رنگ کندل‌ها
   ChartSetInteger(0, CHART_COLOR_CANDLE_BULL, clrGreen);
   ChartSetInteger(0, CHART_COLOR_CANDLE_BEAR, clrRed);
   ChartSetInteger(0, CHART_COLOR_CHART_UP, clrGreen);
   ChartSetInteger(0, CHART_COLOR_CHART_DOWN, clrRed);
   
   // بررسی ورودی‌ها
   if(InpRiskPercent < 0.1 || InpRiskPercent > 10.0)
   {
      Print("خطا: درصد ریسک باید بین 0.1 تا 10.0 باشد");
      return(INIT_PARAMETERS_INCORRECT);
   }
   if(InpFixedTP_RR < 1.0 || InpFixedTP_RR > 5.0)
   {
      Print("خطا: نسبت ریسک به ریوارد باید بین 1.0 تا 5.0 باشد");
      return(INIT_PARAMETERS_INCORRECT);
   }
   // InpSLBufferPips دیگر در CHipoFino استفاده نمیشود، ولی برای اعتبار سنجی کلی بهتر است بماند
   if(InpInitialSLBufferPips < 0) // 👈 اعتبار سنجی جدید
   {
      Print("خطا: بافر حد ضرر اولیه نمی‌تواند منفی باشد");
      return(INIT_PARAMETERS_INCORRECT);
   }
   if(InpHTFFastEMA <= 0 || InpHTFSlowEMA <= InpHTFFastEMA || InpHTFSignal <= 0)
   {
      Print("خطا: تنظیمات مکدی HTF نامعتبر است");
      return(INIT_PARAMETERS_INCORRECT);
   }
   if(InpLTFFastEMA <= 0 || InpLTFSlowEMA <= InpLTFFastEMA || InpLTFSignal <= 0)
   {
      Print("خطا: تنظیمات مکدی LTF نامعتبر است");
      return(INIT_PARAMETERS_INCORRECT);
   }
   if(InpUseSessionFilter && !InpTokyoSession && !InpLondonSession && !InpNewYorkSession &&
      (InpCustomSessionStart == InpCustomSessionEnd))
   {
      Print("خطا: حداقل یک سشن باید فعال باشد یا سشن سفارشی معتبر باشد");
      return(INIT_PARAMETERS_INCORRECT);
   }
   if(!ValidateCustomSessionTime(InpCustomSessionStart) || !ValidateCustomSessionTime(InpCustomSessionEnd))
   {
      Print("خطا: فرمت زمان سشن سفارشی نامعتبر است (باید HH:MM باشد)");
      return(INIT_PARAMETERS_INCORRECT);
   }
   if(InpSarStep <= 0 || InpSarMaximum <= 0)
   {
      Print("خطا: گام یا حداکثر SAR نمی‌تواند صفر یا منفی باشد");
      return(INIT_PARAMETERS_INCORRECT);
   }
   if(InpMinLookback <= 0 || InpMaxLookback < InpMinLookback)
   {
      Print("خطا: تنظیمات دوره کانال CVT نامعتبر است");
      return(INIT_PARAMETERS_INCORRECT);
   }
   if(InpFractalBars <= 0 || InpFractalBufferPips < 0)
   {
      Print("خطا: تنظیمات فراکتال نامعتبر است");
      return(INIT_PARAMETERS_INCORRECT);
   }
   // 👈 اعتبار سنجی برای ATR/MA و فراکتال ساده
   if (InpMAPeriod <= 0 || InpATRPeriod <= 0 || InpATRMultiplier <= 0) {
       Print("خطا: تنظیمات ATR/MA نامعتبر است.");
       return(INIT_PARAMETERS_INCORRECT);
   }
   if (InpSimpleFractalBars <= 0 || InpSimpleFractalPeers <= 0 || InpSimpleFractalBufferPips < 0) {
       Print("خطا: تنظیمات فراکتال ساده نامعتبر است.");
       return(INIT_PARAMETERS_INCORRECT);
   }

   // راه‌اندازی کتابخانه فیبوناچی
   if(!HFiboOnInit())
   {
      Print("خطا: راه‌اندازی کتابخانه HipoFibonacci ناموفق بود");
      return(INIT_FAILED);
   }
   
   // ایجاد نمونه موتور اصلی
g_engine = new CHipoFino(
    // --- گروه ۱: تنظیمات تایم‌فریم و مکدی
    InpHTF, InpLTF,
    InpHTFFastEMA, InpHTFSlowEMA, InpHTFSignal,
    InpLTFFastEMA, InpLTFSlowEMA, InpLTFSignal,

    // --- گروه ۲: تنظیمات عمومی معامله
    InpRiskPercent,
    InpMagicNumber,

    // --- گروه ۳: فیلتر سشن معاملاتی
    InpUseSessionFilter,
    InpTokyoSession,
    InpLondonSession,
    InpNewYorkSession,
    InpCustomSessionStart,
    InpCustomSessionEnd,

    // --- گروه ۴: مدیریت خروج (پله‌ای یا ثابت)
    InpUsePartialTP,
    InpPartialTP_Percentages,
    InpFixedTP_RR,

    // --- گروه ۵: مدیریت حد ضرر متحرک (فعال‌سازی)
    InpUseTrailingStop,
    InpTrailingActivationRR,

    // --- گروه ۶: پارامترهای روش‌های تریلینگ استاپ
    InpStopMethod,
    InpSarStep,
    InpSarMaximum,
    InpMinLookback,
    InpMaxLookback,
    InpFractalBars,
    InpFractalBufferPips,

    // --- گروه ۷: تنظیمات بصری
    InpShowStopLine,
    InpShowFractals,
     // --- گروه ۸: فیلتر ورود با مووینگ اوریج
     InpUseMAEntryFilter,
     InpMAFilterPeriod,
     InpMAFilterMethod,
     InpMAFilterPrice,
     
    // 👈 پارامترهای جدید استاپ لاس اولیه
    InpInitialStopMethod,
    InpInitialSLBufferPips, // 👈 بافر پیپ جدید
    InpATRMATimeframe,
    InpMAMethod,
    InpMAPeriod,
    InpMAPrice,
    InpATRPeriod,
    InpATRMultiplier,
    InpSimpleFractalTimeframe,
    InpSimpleFractalBars,
    InpSimpleFractalPeers,
    InpSimpleFractalBufferPips
);


   if(g_engine == NULL || !g_engine.Initialize())
   {
      Print("خطا: راه‌اندازی موتور اصلی ناموفق بود");
      HFiboOnDeinit(0);
      return(INIT_FAILED);
   }
   
   // ایجاد نمونه داشبورد
   if(InpShowPanel || InpShowMacd)
   {
      g_dashboard = new CHipoDashboard(InpShowPanel, InpShowMacd, InpHTF, InpLTF, InpMagicNumber);
      if(g_dashboard == NULL || !g_dashboard.Initialize())
      {
         Print("خطا: راه‌اندازی داشبورد گرافیکی ناموفق بود");
         delete g_engine;
         HFiboOnDeinit(0);
         return(INIT_FAILED);
      }
   }
   
   Print("اکسپرت HipoFino با موفقیت راه‌اندازی شد");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| تابع توقف اکسپرت                                               |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(g_dashboard != NULL)
   {
      g_dashboard.Deinitialize();
      delete g_dashboard;
      g_dashboard = NULL;
   }
   if(g_engine != NULL)
   {
      g_engine.Deinitialize();
      delete g_engine;
      g_engine = NULL;
   }
   HFiboOnDeinit(reason);
   Print("اکسپرت HipoFino متوقف شد. دلیل: ", reason);
}

//+------------------------------------------------------------------+
//| تابع تیک برای پردازش لحظه‌ای                                    |
//+------------------------------------------------------------------+
void OnTick()
{
   // محدود کردن فرکانس تیک‌ها (هر 100 میلی‌ثانیه)
   datetime current_time = TimeCurrent();
   if(current_time - g_last_tick_time < 100) return;
   g_last_tick_time = current_time;
   
   HFiboOnTick();
   if(g_engine != NULL)
      g_engine.OnTick();
   if(g_dashboard != NULL)
      g_dashboard.Update();
}

//+------------------------------------------------------------------+
//| تابع رویداد چارت (برای کلیک روی پنل تست)                      |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   HFiboOnChartEvent(id, lparam, dparam, sparam);
}
