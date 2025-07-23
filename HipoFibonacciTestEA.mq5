//+------------------------------------------------------------------+
//|                                              HipoFibonacciTest.mq5 |
//|                              محصولی از: Hipo Algorithm           |
//|                              نسخه: ۱.۰.۰                          |
//|                              تاریخ: ۲۰۲۵/۰۷/۲۳                   |
//| اکسپرت تست برای کتابخانه HipoFibonacci با میانبرهای کیبوردی   |
//+------------------------------------------------------------------+

#property copyright "Hipo Algorithm"
#property link      "https://hipoalgorithm.com"
#property version   "1.0.0"

#include <HipoFibonacci.mqh>

//+------------------------------------------------------------------+
//| ورودی‌های اکسپرت                                               |
//+------------------------------------------------------------------+
input group "تنظیمات میانبرهای کیبوردی"
input bool InpEnableHotkeys = true;        // فعال‌سازی میانبرهای کیبوردی
input uchar InpKeyStartLong = 76;          // کلید برای StartLong (L=76)
input uchar InpKeyStartShort = 83;         // کلید برای StartShort (S=83)
input uchar InpKeyStop = 84;               // کلید برای Stop (T=84)

//+------------------------------------------------------------------+
//| متغیرهای جهانی                                                 |
//+------------------------------------------------------------------+
CStructureManager* manager = NULL;

//+------------------------------------------------------------------+
//| تابع اولیه اکسپرت                                              |
//+------------------------------------------------------------------+
int OnInit()
{
   // فعال‌سازی رویدادهای کلیک و کیبورد
   ChartSetInteger(0, CHART_EVENT_OBJECT_CREATE, true);
   ChartSetInteger(0, CHART_EVENT_MOUSE_MOVE, true);
   ChartSetInteger(0, CHART_EVENT_KEYDOWN, true);
   
   // راه‌اندازی مدیر ساختارها
   manager = new CStructureManager();
   if(manager == NULL || !manager.HFiboOnInit())
   {
      Print("خطا: نمی‌توان مدیر ساختارها را راه‌اندازی کرد");
      return INIT_FAILED;
   }
   
   Print("اکسپرت HipoFibonacciTest با موفقیت راه‌اندازی شد");
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| تابع خاتمه اکسپرت                                             |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(manager != NULL)
   {
      manager.HFiboOnDeinit(reason);
      delete manager;
      manager = NULL;
   }
   Print("اکسپرت HipoFibonacciTest متوقف شد. دلیل: ", reason);
}

//+------------------------------------------------------------------+
//| تابع تیک                                                       |
//+------------------------------------------------------------------+
void OnTick()
{
   if(manager != NULL)
      manager.HFiboOnTick();
}

//+------------------------------------------------------------------+
//| تابع کندل جدید                                                |
//+------------------------------------------------------------------+
void OnCalculate(const int rates_total,
                 const int prev_calculated,
                 const datetime &time[],
                 const double &open[],
                 const double &high[],
                 const double &low[],
                 const double &close[],
                 const long &tick_volume[],
                 const long &volume[],
                 const int &spread[])
{
   if(prev_calculated == 0 || rates_total > prev_calculated)
   {
      if(manager != NULL)
         manager.HFiboOnNewBar();
   }
}

//+------------------------------------------------------------------+
//| تابع مدیریت رویدادهای چارت                                    |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
   if(manager != NULL)
      manager.HFiboOnChartEvent(id, lparam, dparam, sparam);
   
   // مدیریت میانبرهای کیبوردی
   if(id == CHARTEVENT_KEYDOWN && InpEnableHotkeys)
   {
      if(lparam == InpKeyStartLong) // کلید L
      {
         Print("میانبر کیبوردی: StartLong (کلید L)");
         if(manager != NULL)
         {
            manager.EnableTestMode(true);
            manager.CreateNewStructure(LONG);
         }
      }
      else if(lparam == InpKeyStartShort) // کلید S
      {
         Print("میانبر کیبوردی: StartShort (کلید S)");
         if(manager != NULL)
         {
            manager.EnableTestMode(true);
            manager.CreateNewStructure(SHORT);
         }
      }
      else if(lparam == InpKeyStop) // کلید T
      {
         Print("میانبر کیبوردی: Stop (کلید T)");
         if(manager != NULL)
         {
            manager.EnableTestMode(false);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| تابع دریافت سیگنال                                             |
//+------------------------------------------------------------------+
void OnTimer()
{
   if(manager != NULL)
   {
      SSignal signal = manager.HFiboGetSignal();
      if(signal.id != "")
      {
         Print("سیگنال دریافت شد: نوع=", signal.type, ", ID=", signal.id);
         manager.AcknowledgeSignal(signal.id);
      }
   }
}

//+------------------------------------------------------------------+
