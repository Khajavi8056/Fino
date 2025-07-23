//+------------------------------------------------------------------+
//|                                              HipoFibonacciTest.mq5 |
//|                              محصولی از: Hipo Algorithm           |
//|                              نسخه: ۱.۱.۰                          |
//|                              تاریخ: ۲۰۲۵/۰۷/۲۳                   |
//| اکسپرت تست ساده برای کتابخانه HipoFibonacci با پنل مینیمال     |
//+------------------------------------------------------------------+

#property copyright "Hipo Algorithm"
#property link      "https://hipoalgorithm.com"
#property version   "1.1.0"

#include <HipoFibonacci.mqh>

//+------------------------------------------------------------------+
//| ورودی‌های اکسپرت                                               |
//+------------------------------------------------------------------+
input group "تنظیمات میانبرهای کیبوردی"
input bool InpEnableHotkeys = true;        // فعال‌سازی میانبرهای کیبوردی
input uchar InpKeyStartLong = 76;          // کلید برای StartLong (L=76)
input uchar InpKeyStartShort = 83;         // کلید برای StartShort (S=83)
input uchar InpKeyStop = 84;               // کلید برای Stop (T=84)

input group "تنظیمات پنل ساده"
input bool InpShowSimplePanel = true;      // نمایش پنل ساده
input int InpPanelOffsetX = 10;            // فاصله افقی پنل از سمت راست (حداقل 0)
input int InpPanelOffsetY = 20;            // فاصله عمودی پنل از بالا (حداقل 0)

//+------------------------------------------------------------------+
//| متغیرهای جهانی                                                 |
//+------------------------------------------------------------------+
CStructureManager* manager = NULL;

//+------------------------------------------------------------------+
//| تابع ایجاد پنل ساده                                            |
//+------------------------------------------------------------------+
bool CreateSimplePanel()
{
   // شیفت چارت برای جلوگیری از تداخل با کندل‌ها
   ChartSetInteger(0, CHART_SHIFT, true);
   ChartSetInteger(0, CHART_MARGIN_RIGHT, 100);

   // ایجاد دکمه StartLong
   if(!ObjectCreate(0, "SimplePanel_StartLong", OBJ_BUTTON, 0, 0, 0))
   {
      Print("خطا: نمی‌توان دکمه StartLong را ایجاد کرد");
      return false;
   }
   ObjectSetInteger(0, "SimplePanel_StartLong", OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, "SimplePanel_StartLong", OBJPROP_XDISTANCE, InpPanelOffsetX);
   ObjectSetInteger(0, "SimplePanel_StartLong", OBJPROP_YDISTANCE, InpPanelOffsetY);
   ObjectSetInteger(0, "SimplePanel_StartLong", OBJPROP_XSIZE, 80);
   ObjectSetInteger(0, "SimplePanel_StartLong", OBJPROP_YSIZE, 30);
   ObjectSetString(0, "SimplePanel_StartLong", OBJPROP_TEXT, "Start Long");
   ObjectSetInteger(0, "SimplePanel_StartLong", OBJPROP_FONTSIZE, 10);
   ObjectSetString(0, "SimplePanel_StartLong", OBJPROP_FONT, "Arial");
   ObjectSetInteger(0, "SimplePanel_StartLong", OBJPROP_ZORDER, 1);

   // ایجاد دکمه StartShort
   if(!ObjectCreate(0, "SimplePanel_StartShort", OBJ_BUTTON, 0, 0, 0))
   {
      Print("خطا: نمی‌توان دکمه StartShort را ایجاد کرد");
      return false;
   }
   ObjectSetInteger(0, "SimplePanel_StartShort", OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, "SimplePanel_StartShort", OBJPROP_XDISTANCE, InpPanelOffsetX);
   ObjectSetInteger(0, "SimplePanel_StartShort", OBJPROP_YDISTANCE, InpPanelOffsetY + 40);
   ObjectSetInteger(0, "SimplePanel_StartShort", OBJPROP_XSIZE, 80);
   ObjectSetInteger(0, "SimplePanel_StartShort", OBJPROP_YSIZE, 30);
   ObjectSetString(0, "SimplePanel_StartShort", OBJPROP_TEXT, "Start Short");
   ObjectSetInteger(0, "SimplePanel_StartShort", OBJPROP_FONTSIZE, 10);
   ObjectSetString(0, "SimplePanel_StartShort", OBJPROP_FONT, "Arial");
   ObjectSetInteger(0, "SimplePanel_StartShort", OBJPROP_ZORDER, 1);

   // ایجاد دکمه Stop
   if(!ObjectCreate(0, "SimplePanel_Stop", OBJ_BUTTON, 0, 0, 0))
   {
      Print("خطا: نمی‌توان دکمه Stop را ایجاد کرد");
      return false;
   }
   ObjectSetInteger(0, "SimplePanel_Stop", OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, "SimplePanel_Stop", OBJPROP_XDISTANCE, InpPanelOffsetX);
   ObjectSetInteger(0, "SimplePanel_Stop", OBJPROP_YDISTANCE, InpPanelOffsetY + 80);
   ObjectSetInteger(0, "SimplePanel_Stop", OBJPROP_XSIZE, 80);
   ObjectSetInteger(0, "SimplePanel_Stop", OBJPROP_YSIZE, 30);
   ObjectSetString(0, "SimplePanel_Stop", OBJPROP_TEXT, "Stop");
   ObjectSetInteger(0, "SimplePanel_Stop", OBJPROP_FONTSIZE, 10);
   ObjectSetString(0, "SimplePanel_Stop", OBJPROP_FONT, "Arial");
   ObjectSetInteger(0, "SimplePanel_Stop", OBJPROP_ZORDER, 1);

   Print("پنل ساده با موفقیت ایجاد شد");
   return true;
}

//+------------------------------------------------------------------+
//| تابع حذف پنل ساده                                              |
//+------------------------------------------------------------------+
void DeleteSimplePanel()
{
   ObjectDelete(0, "SimplePanel_StartLong");
   ObjectDelete(0, "SimplePanel_StartShort");
   ObjectDelete(0, "SimplePanel_Stop");
   Print("پنل ساده حذف شد");
}

//+------------------------------------------------------------------+
//| تابع بررسی کلیک روی دکمه‌ها                                    |
//+------------------------------------------------------------------+
bool HandleButtonClick(string button, string &command)
{
   if(button == "SimplePanel_StartLong" && ObjectGetInteger(0, button, OBJPROP_STATE))
   {
      ObjectSetInteger(0, button, OBJPROP_STATE, false);
      command = "StartLong";
      Print("دکمه StartLong کلیک شد");
      return true;
   }
   if(button == "SimplePanel_StartShort" && ObjectGetInteger(0, button, OBJPROP_STATE))
   {
      ObjectSetInteger(0, button, OBJPROP_STATE, false);
      command = "StartShort";
      Print("دکمه StartShort کلیک شد");
      return true;
   }
   if(button == "SimplePanel_Stop" && ObjectGetInteger(0, button, OBJPROP_STATE))
   {
      ObjectSetInteger(0, button, OBJPROP_STATE, false);
      command = "Stop";
      Print("دکمه Stop کلیک شد");
      return true;
   }
   return false;
}

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

   // غیرفعال کردن پنل تست کتابخانه
   manager.EnableTestMode(false);

   // ایجاد پنل ساده
   if(InpShowSimplePanel && !CreateSimplePanel())
   {
      Print("خطا: نمی‌توان پنل ساده را ایجاد کرد");
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
   if(InpShowSimplePanel)
      DeleteSimplePanel();

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
   // مدیریت کلیک روی دکمه‌ها
   if(id == CHARTEVENT_OBJECT_CLICK && InpShowSimplePanel)
   {
      string command;
      if(HandleButtonClick(sparam, command))
      {
         if(command == "StartLong")
         {
            if(manager != NULL)
               manager.CreateNewStructure(LONG);
         }
         else if(command == "StartShort")
         {
            if(manager != NULL)
               manager.CreateNewStructure(SHORT);
         }
         else if(command == "Stop")
         {
            if(manager != NULL)
               manager.EnableTestMode(false); // توقف همه ساختارها
         }
      }
   }

   // مدیریت میانبرهای کیبوردی
   if(id == CHARTEVENT_KEYDOWN && InpEnableHotkeys)
   {
      if(lparam == InpKeyStartLong) // کلید L
      {
         Print("میانبر کیبوردی: StartLong (کلید L)");
         if(manager != NULL)
            manager.CreateNewStructure(LONG);
      }
      else if(lparam == InpKeyStartShort) // کلید S
      {
         Print("میانبر کیبوردی: StartShort (کلید S)");
         if(manager != NULL)
            manager.CreateNewStructure(SHORT);
      }
      else if(lparam == InpKeyStop) // کلید T
      {
         Print("میانبر کیبوردی: Stop (کلید T)");
         if(manager != NULL)
            manager.EnableTestMode(false);
      }
   }

   // ارسال رویدادهای دیگر به مدیر
   if(manager != NULL)
      manager.HFiboOnChartEvent(id, lparam, dparam, sparam);
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
