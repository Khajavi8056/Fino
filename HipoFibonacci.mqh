
//+------------------------------------------------------------------+
//|                                                  HipoFibonacci.mqh |
//|                              محصولی از: Hipo Algorithm           |
//|                              نسخه: ۱.۷.۲                          |
//|                              تاریخ: ۲۰۲۵/۰۷/۲۴                   |
//+------------------------------------------------------------------+

#property copyright "Hipo Algorithm"
#property link      "https://hipoalgorithm.com"
#property version   "1.7.2"

//+------------------------------------------------------------------+
//| تابع بررسی وجود شیء                                             |
//+------------------------------------------------------------------+
bool CheckObjectExists(string name)
{
   for(int i = 0; i < 3; i++)
   {
      if(ObjectFind(0, name) >= 0) return true;
      Sleep(100);
   }
   Print("خطا: عدم رندر شیء ", name, "، کد خطا: ", GetLastError());
   return false;
}

//+------------------------------------------------------------------+
//| ورودی‌های کتابخانه                                              |
//+------------------------------------------------------------------+
input group "تنظیمات عمومی"
input ENUM_TIMEFRAMES InpTimeframe = PERIOD_CURRENT; // تایم‌فریم محاسبات
input group "تنظیمات فراکتال"
input int InpFractalLookback = 200;       // حداکثر کندل برای جستجوی فراکتال
input int InpFractalPeers = 3;            // تعداد کندل‌های چپ/راست برای فراکتال
input group "سطوح فیبوناچی"
input string InpMotherLevels = "50,61.8,150,200"; // سطوح فیبو مادر
input string InpChildLevels = "50,61.8";         // سطوح فیبو فرزندان
input string InpChild2BreakLevels = "150,200";   // سطوح شکست فرزند دوم
input string InpGoldenZone = "50,61.8";          // ناحیه طلایی
input group "فیکس شدن مادر"
enum ENUM_FIX_MODE { PRICE_CROSS, CANDLE_CLOSE };
input ENUM_FIX_MODE InpMotherFixMode = PRICE_CROSS; // حالت فیکس شدن مادر
input group "رنگ‌بندی اشیاء"
input color InpMotherColor = clrWhite;    // رنگ فیبوناچی مادر
input color InpChild1Color = clrLime;     // رنگ فیبوناچی فرزند اول
input color InpChild2Color = clrGreen;    // رنگ فیبوناچی فرزند دوم
input group "تنظیمات پنل اصلی"
input bool InpShowPanel = true;           // نمایش پنل اصلی
input ENUM_BASE_CORNER InpPanelCorner = CORNER_LEFT_UPPER; // گوشه پنل اصلی
input int InpPanelOffsetX = 10;           // فاصله افقی پنل اصلی
input int InpPanelOffsetY = 20;           // فاصله عمودی پنل اصلی
input group "تنظیمات حالت تست"
input bool InpTestMode = false;           // فعال‌سازی حالت تست
input ENUM_BASE_CORNER InpTestPanelCorner = CORNER_RIGHT_UPPER; // گوشه پنل تست
input int InpTestPanelOffsetX = 153;      // فاصله افقی پنل تست
input int InpTestPanelOffsetY = 39;       // فاصله عمودی پنل تست
input color InpTestPanelButtonColorLong = clrGreen;  // رنگ دکمه Start Long
input color InpTestPanelButtonColorShort = clrRed;   // رنگ دکمه Stop
input color InpTestPanelButtonColorStop = clrGray;   // رنگ دکمه Stop
input color InpTestPanelBgColor = clrDarkGray;      // رنگ پس‌زمینه پنل تست
input group "تنظیمات دیباگ"
input bool InpVisualDebug = false;        // فعال‌سازی دیباگ بصری
input group "تنظیمات لاگ"
input bool InpEnableLog = true;           // فعال‌سازی لاگ
input string InpLogFilePath = "HipoFibonacci_Log.txt"; // مسیر فایل لاگ
input int InpMaxFamilies = 2;             // حداکثر تعداد ساختارهای فعال

//+------------------------------------------------------------------+
//| ساختارها و ثابت‌ها                                              |
//+------------------------------------------------------------------+
enum ENUM_STRUCTURE_STATE
{
   SEARCHING, MOTHER_ACTIVE, CHILD1_ACTIVE, CHILD2_ACTIVE, COMPLETED, FAILED
};

enum ENUM_DIRECTION { LONG, SHORT };

struct SSignal { string type; string id; };
struct SFractal { double price; datetime time; };

//+------------------------------------------------------------------+
//| کلاس CFractalFinder: پیدا کردن فراکتال‌ها                      |
//+------------------------------------------------------------------+
class CFractalFinder
{
private:
   ENUM_TIMEFRAMES m_timeframe;

   bool IsHighFractal(int index, int peers)
   {
      for(int i = 1; i <= peers; i++)
         if(iHigh(_Symbol, m_timeframe, index + i) >= iHigh(_Symbol, m_timeframe, index) ||
            iHigh(_Symbol, m_timeframe, index - i) >= iHigh(_Symbol, m_timeframe, index))
            return false;
      return true;
   }

   bool IsLowFractal(int index, int peers)
   {
      for(int i = 1; i <= peers; i++)
         if(iLow(_Symbol, m_timeframe, index + i) <= iLow(_Symbol, m_timeframe, index) ||
            iLow(_Symbol, m_timeframe, index - i) <= iLow(_Symbol, m_timeframe, index))
            return false;
      return true;
   }

public:
   CFractalFinder(ENUM_TIMEFRAMES timeframe) { m_timeframe = timeframe == PERIOD_CURRENT ? _Period : timeframe; }

   void FindRecentHigh(datetime startTime, int lookback, int peers, SFractal &fractal)
   {
      fractal.price = 0.0; fractal.time = 0;
      int startIndex = iBarShift(_Symbol, m_timeframe, startTime);
      for(int i = startIndex; i <= MathMin(startIndex + lookback, iBars(_Symbol, m_timeframe) - 1); i++)
         if(IsHighFractal(i, peers))
         {
            fractal.price = iHigh(_Symbol, m_timeframe, i);
            fractal.time = iTime(_Symbol, m_timeframe, i);
            break;
         }
   }

   void FindRecentLow(datetime startTime, int lookback, int peers, SFractal &fractal)
   {
      fractal.price = 0.0; fractal.time = 0;
      int startIndex = iBarShift(_Symbol, m_timeframe, startTime);
      for(int i = startIndex; i <= MathMin(startIndex + lookback, iBars(_Symbol, m_timeframe) - 1); i++)
         if(IsLowFractal(i, peers))
         {
            fractal.price = iLow(_Symbol, m_timeframe, i);
            fractal.time = iTime(_Symbol, m_timeframe, i);
            break;
         }
   }
};

//+------------------------------------------------------------------+
//| کلاس CPanel: پنل اصلی اطلاعاتی                                  |
//+------------------------------------------------------------------+
class CPanel
{
private:
   string m_name;
   ENUM_BASE_CORNER m_corner;
   int m_offset_x, m_offset_y;
   int m_flash_counter;
   uint m_last_status_time;

   bool CreateLabel(string name, string text, int x, int y, color clr, int font_size, string font)
   {
      if(!ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0)) return false;
      ObjectSetInteger(0, name, OBJPROP_CORNER, m_corner);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
      ObjectSetString(0, name, OBJPROP_TEXT, text);
      ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, font_size);
      ObjectSetString(0, name, OBJPROP_FONT, font);
      ObjectSetInteger(0, name, OBJPROP_ZORDER, 1);
      return CheckObjectExists(name);
   }

   bool CreateBackground(string name, int x, int y)
   {
      if(!ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0)) return false;
      ObjectSetInteger(0, name, OBJPROP_CORNER, m_corner);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
      ObjectSetInteger(0, name, OBJPROP_XSIZE, 300);
      ObjectSetInteger(0, name, OBJPROP_YSIZE, 90);
      ObjectSetInteger(0, name, OBJPROP_BGCOLOR, clrDarkSlateGray);
      ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, name, OBJPROP_ZORDER, -1);
      return CheckObjectExists(name);
   }

   bool CreateHeader(string name, int x, int y)
   {
      if(!ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0)) return false;
      ObjectSetInteger(0, name, OBJPROP_CORNER, m_corner);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
      ObjectSetInteger(0, name, OBJPROP_XSIZE, 300);
      ObjectSetInteger(0, name, OBJPROP_YSIZE, 20);
      ObjectSetInteger(0, name, OBJPROP_BGCOLOR, clrMidnightBlue);
      ObjectSetInteger(0, name, OBJPROP_ZORDER, 0);
      return CheckObjectExists(name);
   }

public:
   CPanel(string name, ENUM_BASE_CORNER corner, int x, int y)
   {
      m_name = name; m_corner = corner; m_offset_x = x; m_offset_y = y;
      m_flash_counter = 0; m_last_status_time = 0;
   }

   bool Create()
   {
      return CreateBackground(m_name + "_Bg", m_offset_x, m_offset_y) &&
             CreateHeader(m_name + "_Header", m_offset_x, m_offset_y) &&
             CreateLabel(m_name + "_Title", "Hipo Fibonacci v1.7.2 - 2025/07/24", m_offset_x + 10, m_offset_y + 5, clrWhite, 11, "Calibri Bold") &&
             CreateLabel(m_name + "_Status", "وضعیت: در حال انتظار", m_offset_x + 10, m_offset_y + 35, clrLightGray, 9, "Calibri") &&
             CreateLabel(m_name + "_Command", "دستور: هیچ", m_offset_x + 10, m_offset_y + 65, clrLightGray, 9, "Calibri");
   }

   void UpdateStatus(string status, bool is_error = false)
   {
      m_flash_counter = (m_flash_counter + 1) % 40;
      color status_color = is_error ? clrRed : (m_flash_counter < 20 ? clrLightYellow : clrWhite);
      ObjectSetString(0, m_name + "_Status", OBJPROP_TEXT, "وضعیت: " + status);
      ObjectSetInteger(0, m_name + "_Status", OBJPROP_COLOR, status_color);
      m_last_status_time = GetTickCount();
   }

   void UpdateCommand(string command)
   {
      ObjectSetString(0, m_name + "_Command", OBJPROP_TEXT, "دستور: " + command);
   }

   void UpdateTestStatus(string status)
   {
      m_flash_counter = (m_flash_counter + 1) % 40;
      color status_color = m_flash_counter < 20 ? clrLightYellow : clrWhite;
      ObjectSetString(0, m_name + "_Status", OBJPROP_TEXT, "حالت تست: " + status);
      ObjectSetInteger(0, m_name + "_Status", OBJPROP_COLOR, status_color);
      m_last_status_time = GetTickCount();
   }

   bool ShouldResetStatus() { return (GetTickCount() - m_last_status_time >= 5000); }
   void ResetStatus() { UpdateStatus("در حال انتظار"); }
   void Destroy()
   {
      ObjectDelete(0, m_name + "_Bg");
      ObjectDelete(0, m_name + "_Header");
      ObjectDelete(0, m_name + "_Title");
      ObjectDelete(0, m_name + "_Status");
      ObjectDelete(0, m_name + "_Command");
   }
};

//+------------------------------------------------------------------+
//| کلاس CTestPanel: پنل تست دستی                                   |
//+------------------------------------------------------------------+
class CTestPanel
{
private:
   string m_name;
   ENUM_BASE_CORNER m_corner;
   int m_offset_x, m_offset_y;
   color m_button_color_long, m_button_color_short, m_button_color_stop, m_bg_color;

   bool CreateButton(string name, string text, int x, int y, color clr)
   {
      if(!ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0)) return false;
      ObjectSetInteger(0, name, OBJPROP_CORNER, m_corner);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
      ObjectSetInteger(0, name, OBJPROP_XSIZE, 100);
      ObjectSetInteger(0, name, OBJPROP_YSIZE, 30);
      ObjectSetString(0, name, OBJPROP_TEXT, text);
      ObjectSetInteger(0, name, OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, name, OBJPROP_BGCOLOR, clr);
      ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_RAISED);
      ObjectSetInteger(0, name, OBJPROP_ZORDER, 2);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      return CheckObjectExists(name);
   }

   bool CreateBackground(string name, int x, int y)
   {
      if(!ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0)) return false;
      ObjectSetInteger(0, name, OBJPROP_CORNER, m_corner);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
      ObjectSetInteger(0, name, OBJPROP_XSIZE, 320);
      ObjectSetInteger(0, name, OBJPROP_YSIZE, 70);
      ObjectSetInteger(0, name, OBJPROP_BGCOLOR, m_bg_color);
      ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, name, OBJPROP_ZORDER, -1);
      return CheckObjectExists(name);
   }

   bool CreateSignalLabel(string name, int x, int y)
   {
      if(!ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0)) return false;
      ObjectSetInteger(0, name, OBJPROP_CORNER, m_corner);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
      ObjectSetString(0, name, OBJPROP_TEXT, "آخرین سیگنال: هیچ");
      ObjectSetInteger(0, name, OBJPROP_COLOR, clrLightGray);
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 9);
      ObjectSetString(0, name, OBJPROP_FONT, "Calibri");
      ObjectSetInteger(0, name, OBJPROP_ZORDER, 1);
      return CheckObjectExists(name);
   }

public:
   CTestPanel(string name, ENUM_BASE_CORNER corner, int x, int y, color long_color, color short_color, color stop_color, color bg_color)
   {
      m_name = name; m_corner = corner; m_offset_x = x; m_offset_y = y;
      m_button_color_long = long_color; m_button_color_short = short_color;
      m_button_color_stop = stop_color; m_bg_color = bg_color;
   }

   bool Create()
   {
      bool success = CreateBackground(m_name + "_Bg", m_offset_x, m_offset_y) &&
                     CreateButton(m_name + "_StartLong", "Start Long", m_offset_x + 10, m_offset_y + 5, m_button_color_long) &&
                     CreateButton(m_name + "_StartShort", "Start Short", m_offset_x + 110, m_offset_y + 5, m_button_color_short) &&
                     CreateButton(m_name + "_Stop", "Stop", m_offset_x + 210, m_offset_y + 5, m_button_color_stop) &&
                     CreateSignalLabel(m_name + "_Signal", m_offset_x + 10, m_offset_y + 40);
      if(success && InpEnableLog) Print("پنل تست ایجاد شد: ", m_name);
      return success;
   }

   bool OnButtonClick(string button, string &command)
   {
      if(ObjectGetInteger(0, button, OBJPROP_STATE))
      {
         ObjectSetInteger(0, button, OBJPROP_STATE, false);
         ObjectSetInteger(0, button, OBJPROP_BGCOLOR, C'100,100,100');
         Sleep(100);
         if(StringFind(button, "_StartLong") >= 0)
         {
            command = "StartLong";
            ObjectSetInteger(0, button, OBJPROP_BGCOLOR, m_button_color_long);
            if(InpEnableLog) Print("دکمه StartLong کلیک شد");
            return true;
         }
         if(StringFind(button, "_StartShort") >= 0)
         {
            command = "StartShort";
            ObjectSetInteger(0, button, OBJPROP_BGCOLOR, m_button_color_short);
            if(InpEnableLog) Print("دکمه StartShort کلیک شد");
            return true;
         }
         if(StringFind(button, "_Stop") >= 0)
         {
            command = "Stop";
            ObjectSetInteger(0, button, OBJPROP_BGCOLOR, m_button_color_stop);
            if(InpEnableLog) Print("دکمه Stop کلیک شد");
            return true;
         }
      }
      return false;
   }

   void UpdateSignal(string signal_type, string signal_id)
   {
      string text = signal_id == "" ? "آخرین سیگنال: هیچ" : "آخرین سیگنال: " + signal_type + " (ID: " + signal_id + ")";
      ObjectSetString(0, m_name + "_Signal", OBJPROP_TEXT, text);
      ObjectSetInteger(0, m_name + "_Signal", OBJPROP_COLOR, signal_type == "Buy" ? clrLimeGreen : (signal_type == "Sell" ? clrRed : clrLightGray));
   }

   void Destroy()
   {
      ObjectDelete(0, m_name + "_Bg");
      ObjectDelete(0, m_name + "_StartLong");
      ObjectDelete(0, m_name + "_StartShort");
      ObjectDelete(0, m_name + "_Stop");
      ObjectDelete(0, m_name + "_Signal");
   }
};

//+------------------------------------------------------------------+
//| کلاس CBaseFibo: پایه فیبوناچی‌ها                               |
//+------------------------------------------------------------------+
class CBaseFibo
{
protected:
   string m_name;
   color m_color;
   double m_levels[];
   datetime m_time0, m_time100;
   double m_price0, m_price100;
   bool m_is_test;
   string m_debug_objects[];

   void CleanUpDebugObjects()
   {
      for(int i = ArraySize(m_debug_objects) - 1; i >= 0; i--)
      {
         ObjectDelete(0, m_debug_objects[i]);
         ArrayRemove(m_debug_objects, i, 1);
      }
   }

public:
   CBaseFibo(string name, color clr, string levels, bool is_test)
   {
      m_name = name; m_color = clr; m_is_test = is_test;
      string temp_levels[];
      int count = StringSplit(levels, StringGetCharacter(",", 0), temp_levels);
      ArrayResize(m_levels, count);
      for(int i = 0; i < count; i++) m_levels[i] = StringToDouble(temp_levels[i]);
      ArrayResize(m_debug_objects, 0);
   }

   virtual bool Draw()
   {
      string obj_name = m_name + (m_is_test ? "_Test" : "");
      if(!ObjectCreate(0, obj_name, OBJ_FIBO, 0, m_time0, m_price0, m_time100, m_price100)) return false;
      ObjectSetInteger(0, obj_name, OBJPROP_LEVELS, ArraySize(m_levels));
      ObjectSetInteger(0, obj_name, OBJPROP_COLOR, m_color);
      ObjectSetInteger(0, obj_name, OBJPROP_STYLE, STYLE_SOLID);
      for(int i = 0; i < ArraySize(m_levels); i++)
         ObjectSetDouble(0, obj_name, OBJPROP_LEVELVALUE, i, m_levels[i] / 100.0);
      return CheckObjectExists(obj_name);
   }

   void Delete()
   {
      ObjectDelete(0, m_name + (m_is_test ? "_Test" : ""));
      CleanUpDebugObjects();
   }

   datetime GetTime0() { return m_time0; }
   double GetPrice0() { return m_price0; }
   double GetPrice100() { return m_price100; }
};

//+------------------------------------------------------------------+
//| کلاس CMotherFibo: فیبوناچی مادر                                |
//+------------------------------------------------------------------+
class CMotherFibo : public CBaseFibo
{
private:
   bool m_is_fixed;
   ENUM_DIRECTION m_direction;
   ENUM_TIMEFRAMES m_timeframe;
   string m_zero_line_name;

   void Log(string message)
   {
      if(InpEnableLog) Print(TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES | TIME_SECONDS), ": ", message);
   }

public:
   CMotherFibo(string name, color clr, string levels, ENUM_DIRECTION dir, bool is_test, ENUM_TIMEFRAMES timeframe)
      : CBaseFibo(name, clr, levels, is_test)
   {
      m_is_fixed = false; m_direction = dir; m_timeframe = timeframe == PERIOD_CURRENT ? _Period : timeframe;
      m_zero_line_name = "";
   }

   virtual bool Draw() override
   {
      string obj_name = m_name + (m_is_test ? "_Test" : "");
      if(!ObjectCreate(0, obj_name, OBJ_FIBO, 0, m_time100, m_price100, m_time0, m_price0)) return false;
      ObjectSetInteger(0, obj_name, OBJPROP_LEVELS, ArraySize(m_levels));
      ObjectSetInteger(0, obj_name, OBJPROP_COLOR, m_color);
      ObjectSetInteger(0, obj_name, OBJPROP_STYLE, STYLE_SOLID);
      for(int i = 0; i < ArraySize(m_levels); i++)
         ObjectSetDouble(0, obj_name, OBJPROP_LEVELVALUE, i, m_levels[i] / 100.0);
      return CheckObjectExists(obj_name);
   }

   bool Initialize(SFractal &fractal, datetime current_time)
   {
      m_time100 = fractal.time; m_price100 = fractal.price;
      double min_max_price = m_direction == LONG ? iLow(_Symbol, m_timeframe, iBarShift(_Symbol, m_timeframe, fractal.time)) :
                                                  iHigh(_Symbol, m_timeframe, iBarShift(_Symbol, m_timeframe, fractal.time));
      datetime min_max_time = fractal.time;
      int start_index = iBarShift(_Symbol, m_timeframe, fractal.time);
      int end_index = iBarShift(_Symbol, m_timeframe, current_time);
      for(int i = start_index; i >= end_index; i--)
      {
         double price = m_direction == LONG ? iLow(_Symbol, m_timeframe, i) : iHigh(_Symbol, m_timeframe, i);
         if(m_direction == LONG && price < min_max_price)
         {
            min_max_price = price; min_max_time = iTime(_Symbol, m_timeframe, i);
         }
         else if(m_direction == SHORT && price > min_max_price)
         {
            min_max_price = price; min_max_time = iTime(_Symbol, m_timeframe, i);
         }
      }
      m_price0 = min_max_price; m_time0 = min_max_time;
      if(Draw())
      {
         Log("مادر متولد شد: صد=", DoubleToString(m_price100, _Digits), ", صفر=", DoubleToString(m_price0, _Digits));
         if(InpVisualDebug)
         {
            string arrow_name = "Debug_Arrow_Fractal_" + TimeToString(m_time100) + (m_is_test ? "_Test" : "");
            if(ObjectCreate(0, arrow_name, m_direction == LONG ? OBJ_ARROW_UP : OBJ_ARROW_DOWN, 0, m_time100, m_price100))
            {
               ObjectSetInteger(0, arrow_name, OBJPROP_COLOR, m_direction == LONG ? clrSkyBlue : clrOrangeRed);
               ArrayResize(m_debug_objects, ArraySize(m_debug_objects) + 1);
               m_debug_objects[ArraySize(m_debug_objects) - 1] = arrow_name;
               CheckObjectExists(arrow_name);
            }
            string label_name = "Debug_Label_MotherBirth_" + TimeToString(m_time100) + (m_is_test ? "_Test" : "");
            if(ObjectCreate(0, label_name, OBJ_TEXT, 0, m_time100, m_price100))
            {
               ObjectSetString(0, label_name, OBJPROP_TEXT, "مادر متولد شد");
               ObjectSetInteger(0, label_name, OBJPROP_COLOR, clrWhite);
               ArrayResize(m_debug_objects, ArraySize(m_debug_objects) + 1);
               m_debug_objects[ArraySize(m_debug_objects) - 1] = label_name;
            }
            m_zero_line_name = "Debug_HLine_MotherZero_" + m_name + (m_is_test ? "_Test" : "");
            if(ObjectCreate(0, m_zero_line_name, OBJ_HLINE, 0, 0, m_price0))
            {
               ObjectSetInteger(0, m_zero_line_name, OBJPROP_COLOR, clrGray);
               ObjectSetInteger(0, m_zero_line_name, OBJPROP_STYLE, STYLE_DOT);
               ArrayResize(m_debug_objects, ArraySize(m_debug_objects) + 1);
               m_debug_objects[ArraySize(m_debug_objects) - 1] = m_zero_line_name;
               CheckObjectExists(m_zero_line_name);
            }
         }
         return true;
      }
      return false;
   }

   bool UpdateOnTick(datetime new_time)
   {
      if(m_is_fixed) return true;
      double old_price0 = m_price0; datetime old_time0 = m_time0;
      int current_index = iBarShift(_Symbol, m_timeframe, new_time);
      if(m_direction == LONG)
      {
         m_price0 = MathMin(m_price0, iLow(_Symbol, m_timeframe, current_index));
         if(m_price0 != old_price0) m_time0 = iTime(_Symbol, m_timeframe, current_index);
      }
      else
      {
         m_price0 = MathMax(m_price0, iHigh(_Symbol, m_timeframe, current_index));
         if(m_price0 != old_price0) m_time0 = iTime(_Symbol, m_timeframe, current_index);
      }
      if(m_price0 != old_price0)
      {
         string obj_name = m_name + (m_is_test ? "_Test" : "");
         if(CheckObjectExists(obj_name) && ObjectMove(0, obj_name, 1, m_time0, m_price0))
         {
            Log("صفر مادر آپدیت شد: صفر=", DoubleToString(m_price0, _Digits));
            if(InpVisualDebug && m_zero_line_name != "" && CheckObjectExists(m_zero_line_name))
               ObjectMove(0, m_zero_line_name, 0, 0, m_price0);
            else if(InpVisualDebug && m_zero_line_name == "")
            {
               m_zero_line_name = "Debug_HLine_MotherZero_" + m_name + (m_is_test ? "_Test" : "");
               if(ObjectCreate(0, m_zero_line_name, OBJ_HLINE, 0, 0, m_price0))
               {
                  ObjectSetInteger(0, m_zero_line_name, OBJPROP_COLOR, clrGray);
                  ObjectSetInteger(0, m_zero_line_name, OBJPROP_STYLE, STYLE_DOT);
                  ArrayResize(m_debug_objects, ArraySize(m_debug_objects) + 1);
                  m_debug_objects[ArraySize(m_debug_objects) - 1] = m_zero_line_name;
                  CheckObjectExists(m_zero_line_name);
               }
            }
            return true;
         }
         Print("خطا: جابجایی فیبوناچی مادر ", obj_name, " ناموفق، کد خطا: ", GetLastError());
         return false;
      }
      return true;
   }

   bool CheckFixingPriceCross(double current_price)
   {
      if(m_is_fixed) return true;
      double level_50 = m_price100 + (m_price0 - m_price100) * 0.5;
      bool fix_condition = (m_direction == LONG && current_price >= level_50) ||
                           (m_direction == SHORT && current_price <= level_50);
      if(fix_condition)
      {
         m_is_fixed = true;
         Log("مادر فیکس شد (عبور قیمت)");
         if(InpVisualDebug)
         {
            string arrow_name = "Debug_Arrow_MotherFix_" + TimeToString(TimeCurrent()) + (m_is_test ? "_Test" : "");
            if(ObjectCreate(0, arrow_name, m_direction == LONG ? OBJ_ARROW_UP : OBJ_ARROW_DOWN, 0, TimeCurrent(), current_price))
            {
               ObjectSetInteger(0, arrow_name, OBJPROP_COLOR, m_direction == LONG ? clrLimeGreen : clrMagenta);
               ArrayResize(m_debug_objects, ArraySize(m_debug_objects) + 1);
               m_debug_objects[ArraySize(m_debug_objects) - 1] = arrow_name;
               CheckObjectExists(arrow_name);
            }
            string label_name = "Debug_Label_MotherFix_" + TimeToString(TimeCurrent()) + (m_is_test ? "_Test" : "");
            if(ObjectCreate(0, label_name, OBJ_TEXT, 0, TimeCurrent(), m_price0))
            {
               ObjectSetString(0, label_name, OBJPROP_TEXT, "مادر فیکس شد");
               ObjectSetInteger(0, label_name, OBJPROP_COLOR, clrWhite);
               ArrayResize(m_debug_objects, ArraySize(m_debug_objects) + 1);
               m_debug_objects[ArraySize(m_debug_objects) - 1] = label_name;
            }
         }
         return true;
      }
      return false;
   }

   bool CheckFixingCandleClose()
   {
      if(m_is_fixed) return true;
      double level_50 = m_price100 + (m_price0 - m_price100) * 0.5;
      bool fix_condition = (m_direction == LONG && iClose(_Symbol, m_timeframe, 1) >= level_50) ||
                           (m_direction == SHORT && iClose(_Symbol, m_timeframe, 1) <= level_50);
      if(fix_condition)
      {
         m_is_fixed = true;
         Log("مادر فیکس شد (کلوز کندل)");
         if(InpVisualDebug)
         {
            string arrow_name = "Debug_Arrow_MotherFix_" + TimeToString(TimeCurrent()) + (m_is_test ? "_Test" : "");
            if(ObjectCreate(0, arrow_name, m_direction == LONG ? OBJ_ARROW_UP : OBJ_ARROW_DOWN, 0, TimeCurrent(), iClose(_Symbol, m_timeframe, 1)))
            {
               ObjectSetInteger(0, arrow_name, OBJPROP_COLOR, m_direction == LONG ? clrLimeGreen : clrMagenta);
               ArrayResize(m_debug_objects, ArraySize(m_debug_objects) + 1);
               m_debug_objects[ArraySize(m_debug_objects) - 1] = arrow_name;
               CheckObjectExists(arrow_name);
            }
            string label_name = "Debug_Label_MotherFix_" + TimeToString(TimeCurrent()) + (m_is_test ? "_Test" : "");
            if(ObjectCreate(0, label_name, OBJ_TEXT, 0, TimeCurrent(), m_price0))
            {
               ObjectSetString(0, label_name, OBJPROP_TEXT, "مادر فیکس شد");
               ObjectSetInteger(0, label_name, OBJPROP_COLOR, clrWhite);
               ArrayResize(m_debug_objects, ArraySize(m_debug_objects) + 1);
               m_debug_objects[ArraySize(m_debug_objects) - 1] = label_name;
            }
         }
         return true;
      }
      return false;
   }

   bool CheckStructureFailure(double current_price)
   {
      if(!m_is_fixed) return false;
      double level_0 = m_price0;
      bool fail_condition = (m_direction == LONG && current_price <= level_0) ||
                            (m_direction == SHORT && current_price >= level_0);
      if(fail_condition)
      {
         Log("ساختار شکست خورد: لنگرگاه مادر سوراخ شد");
         if(InpVisualDebug)
         {
            string label_name = "Debug_Label_StructureFail_" + TimeToString(TimeCurrent()) + (m_is_test ? "_Test" : "");
            if(ObjectCreate(0, label_name, OBJ_TEXT, 0, TimeCurrent(), current_price))
            {
               ObjectSetString(0, label_name, OBJPROP_TEXT, "ساختار شکست خورد");
               ObjectSetInteger(0, label_name, OBJPROP_COLOR, clrRed);
               ArrayResize(m_debug_objects, ArraySize(m_debug_objects) + 1);
               m_debug_objects[ArraySize(m_debug_objects) - 1] = label_name;
            }
         }
         return true;
      }
      return false;
   }

   bool IsFixed() { return m_is_fixed; }
   ENUM_DIRECTION GetDirection() { return m_direction; }
};

//+------------------------------------------------------------------+
//| کلاس CChildFibo: فیبوناچی فرزند                                |
//+------------------------------------------------------------------+
class CChildFibo : public CBaseFibo
{
private:
   bool m_is_fixed;
   bool m_is_success_child2;
   CMotherFibo* m_parent_mother;
   ENUM_TIMEFRAMES m_timeframe;
   string m_hundred_line_name;

   void Log(string message)
   {
      if(InpEnableLog) Print(TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES | TIME_SECONDS), ": ", message);
   }

public:
   CChildFibo(string name, color clr, string levels, CMotherFibo* mother, bool is_success_child2, bool is_test, ENUM_TIMEFRAMES timeframe)
      : CBaseFibo(name, clr, levels, is_test)
   {
      m_is_fixed = false; m_is_success_child2 = is_success_child2; m_parent_mother = mother;
      m_timeframe = timeframe == PERIOD_CURRENT ? _Period : timeframe; m_hundred_line_name = "";
   }

   bool Initialize(datetime current_time)
   {
      if(m_parent_mother == NULL) return false;
      m_time0 = m_parent_mother.GetTime0(); m_price0 = m_parent_mother.GetPrice0();
      int current_index = iBarShift(_Symbol, m_timeframe, current_time);
      int mother_index = iBarShift(_Symbol, m_timeframe, m_time0);
      if(m_parent_mother.GetDirection() == LONG)
      {
         m_price100 = iHigh(_Symbol, m_timeframe, current_index);
         for(int i = mother_index; i >= current_index; i--)
            m_price100 = MathMax(m_price100, iHigh(_Symbol, m_timeframe, i));
      }
      else
      {
         m_price100 = iLow(_Symbol, m_timeframe, current_index);
         for(int i = mother_index; i >= current_index; i--)
            m_price100 = MathMin(m_price100, iLow(_Symbol, m_timeframe, i));
      }
      m_time100 = current_time;
      if(Draw())
      {
         Log("فرزند ", (StringFind(m_name, "Child1") >= 0 ? "اول" : (m_is_success_child2 ? "دوم (موفق)" : "دوم (ناموفق)")), " متولد شد");
         if(InpVisualDebug)
         {
            string arrow_name = "Debug_Arrow_" + (StringFind(m_name, "Child1") >= 0 ? "Child1Birth_" : "Child2Birth_") + TimeToString(m_time100) + (m_is_test ? "_Test" : "");
            if(ObjectCreate(0, arrow_name, m_parent_mother.GetDirection() == LONG ? OBJ_ARROW_UP : OBJ_ARROW_DOWN, 0, m_time100, m_price100))
            {
               ObjectSetInteger(0, arrow_name, OBJPROP_COLOR, StringFind(m_name, "Child1") >= 0 ? (m_parent_mother.GetDirection() == LONG ? clrCyan : clrPink) :
                                                               (m_parent_mother.GetDirection() == LONG ? clrDarkGreen : clrDarkRed));
               ArrayResize(m_debug_objects, ArraySize(m_debug_objects) + 1);
               m_debug_objects[ArraySize(m_debug_objects) - 1] = arrow_name;
               CheckObjectExists(arrow_name);
            }
            m_hundred_line_name = "Debug_HLine_" + (StringFind(m_name, "Child1") >= 0 ? "Child1Hundred_" : "Child2Hundred_") + m_name + (m_is_test ? "_Test" : "");
            if(ObjectCreate(0, m_hundred_line_name, OBJ_HLINE, 0, 0, m_price100))
            {
               ObjectSetInteger(0, m_hundred_line_name, OBJPROP_COLOR, clrLightGray);
               ObjectSetInteger(0, m_hundred_line_name, OBJPROP_STYLE, STYLE_DOT);
               ArrayResize(m_debug_objects, ArraySize(m_debug_objects) + 1);
               m_debug_objects[ArraySize(m_debug_objects) - 1] = m_hundred_line_name;
               CheckObjectExists(m_hundred_line_name);
            }
         }
         return true;
      }
      return false;
   }

   bool UpdateOnTick(datetime new_time)
   {
      if(m_is_fixed || m_parent_mother == NULL) return true;
      double old_price100 = m_price100;
      int current_index = iBarShift(_Symbol, m_timeframe, new_time);
      if(m_parent_mother.GetDirection() == LONG)
         m_price100 = MathMax(m_price100, iHigh(_Symbol, m_timeframe, current_index));
      else
         m_price100 = MathMin(m_price100, iLow(_Symbol, m_timeframe, current_index));
      if(m_price100 != old_price100)
      {
         m_time100 = new_time;
         string obj_name = m_name + (m_is_test ? "_Test" : "");
         if(CheckObjectExists(obj_name) && ObjectMove(0, obj_name, 1, m_time100, m_price100))
         {
            Log("صد فرزند ", (StringFind(m_name, "Child1") >= 0 ? "اول" : (m_is_success_child2 ? "دوم (موفق)" : "دوم (ناموفق)")), " آپدیت شد");
            if(InpVisualDebug && m_hundred_line_name != "" && CheckObjectExists(m_hundred_line_name))
               ObjectMove(0, m_hundred_line_name, 0, 0, m_price100);
            else if(InpVisualDebug && m_hundred_line_name == "")
            {
               m_hundred_line_name = "Debug_HLine_" + (StringFind(m_name, "Child1") >= 0 ? "Child1Hundred_" : "Child2Hundred_") + m_name + (m_is_test ? "_Test" : "");
               if(ObjectCreate(0, m_hundred_line_name, OBJ_HLINE, 0, 0, m_price100))
               {
                  ObjectSetInteger(0, m_hundred_line_name, OBJPROP_COLOR, clrLightGray);
                  ObjectSetInteger(0, m_hundred_line_name, OBJPROP_STYLE, STYLE_DOT);
                  ArrayResize(m_debug_objects, ArraySize(m_debug_objects) + 1);
                  m_debug_objects[ArraySize(m_debug_objects) - 1] = m_hundred_line_name;
                  CheckObjectExists(m_hundred_line_name);
               }
            }
            return true;
         }
         Print("خطا: جابجایی فیبوناچی فرزند ", obj_name, " ناموفق، کد خطا: ", GetLastError());
         return false;
      }
      return true;
   }

   bool CheckFixing(double current_price)
   {
      if(m_is_fixed || StringFind(m_name, "Child2") >= 0 || m_parent_mother == NULL) return false;
      double level_50 = m_price100 + (m_price0 - m_price100) * 0.5;
      bool fix_condition = (m_parent_mother.GetDirection() == LONG && current_price <= level_50) ||
                           (m_parent_mother.GetDirection() == SHORT && current_price >= level_50);
      if(fix_condition)
      {
         m_is_fixed = true;
         Log("فرزند اول فیکس شد");
         if(InpVisualDebug)
         {
            string arrow_name = "Debug_Arrow_Child1Fix_" + TimeToString(TimeCurrent()) + (m_is_test ? "_Test" : "");
            if(ObjectCreate(0, arrow_name, m_parent_mother.GetDirection() == LONG ? OBJ_ARROW_DOWN : OBJ_ARROW_UP, 0, TimeCurrent(), current_price))
            {
               ObjectSetInteger(0, arrow_name, OBJPROP_COLOR, m_parent_mother.GetDirection() == LONG ? clrGreen : clrRed);
               ArrayResize(m_debug_objects, ArraySize(m_debug_objects) + 1);
               m_debug_objects[ArraySize(m_debug_objects) - 1] = arrow_name;
               CheckObjectExists(arrow_name);
            }
            string label_name = "Debug_Label_Child1Fix_" + TimeToString(TimeCurrent()) + (m_is_test ? "_Test" : "");
            if(ObjectCreate(0, label_name, OBJ_TEXT, 0, TimeCurrent(), m_price100))
            {
               ObjectSetString(0, label_name, OBJPROP_TEXT, "فرزند اول فیکس شد");
               ObjectSetInteger(0, label_name, OBJPROP_COLOR, clrWhite);
               ArrayResize(m_debug_objects, ArraySize(m_debug_objects) + 1);
               m_debug_objects[ArraySize(m_debug_objects) - 1] = label_name;
            }
         }
         return true;
      }
      return false;
   }

   bool CheckChild1TriggerChild2(double current_price)
   {
      if(m_is_fixed && StringFind(m_name, "Child1") >= 0 && m_parent_mother != NULL)
      {
         bool trigger_condition = (m_parent_mother.GetDirection() == LONG && current_price > m_price100) ||
                                 (m_parent_mother.GetDirection() == SHORT && current_price < m_price100);
         if(trigger_condition)
         {
            Log("فرزند دوم (موفق) فعال شد");
            return true;
         }
      }
      return false;
   }

   bool CheckFailure(double current_price)
   {
      if(m_is_fixed || m_parent_mother == NULL) return false;
      double mother_100_level = m_parent_mother.GetPrice100();
      bool fail_condition = (m_parent_mother.GetDirection() == LONG && current_price > mother_100_level) ||
                            (m_parent_mother.GetDirection() == SHORT && current_price < mother_100_level);
      if(fail_condition)
      {
         Log("فرزند ", (StringFind(m_name, "Child1") >= 0 ? "اول" : (m_is_success_child2 ? "دوم (موفق)" : "دوم (ناموفق)")), " شکست خورد");
         if(InpVisualDebug)
         {
            string label_name = "Debug_Label_ChildFail_" + TimeToString(TimeCurrent()) + (m_is_test ? "_Test" : "");
            if(ObjectCreate(0, label_name, OBJ_TEXT, 0, TimeCurrent(), current_price))
            {
               ObjectSetString(0, label_name, OBJPROP_TEXT, "فرزند شکست خورد");
               ObjectSetInteger(0, label_name, OBJPROP_COLOR, clrRed);
               ArrayResize(m_debug_objects, ArraySize(m_debug_objects) + 1);
               m_debug_objects[ArraySize(m_debug_objects) - 1] = label_name;
            }
         }
         return true;
      }
      return false;
   }

   bool CheckSuccessChild2(double current_price)
   {
      if(!m_is_success_child2 || m_parent_mother == NULL) return false;
      double level_50 = m_price100 + (m_price0 - m_price100) * 0.5;
      double level_618 = m_price100 + (m_price0 - m_price100) * 0.618;
      bool success_condition = (m_parent_mother.GetDirection() == LONG && current_price >= level_50 && current_price <= level_618) ||
                               (m_parent_mother.GetDirection() == SHORT && current_price <= level_50 && current_price >= level_618);
      if(success_condition)
      {
         Log("فرزند دوم موفق شد (ناحیه طلایی)");
         if(InpVisualDebug)
         {
            string rect_name = "Debug_Rect_GoldenZone_" + TimeToString(TimeCurrent()) + (m_is_test ? "_Test" : "");
            if(ObjectCreate(0, rect_name, OBJ_RECTANGLE, 0, TimeCurrent(), level_50, TimeCurrent() + PeriodSeconds(m_timeframe), level_618))
            {
               ObjectSetInteger(0, rect_name, OBJPROP_COLOR, clrLightYellow);
               ObjectSetInteger(0, rect_name, OBJPROP_FILL, true);
               ArrayResize(m_debug_objects, ArraySize(m_debug_objects) + 1);
               m_debug_objects[ArraySize(m_debug_objects) - 1] = rect_name;
               CheckObjectExists(rect_name);
            }
            string arrow_name = "Debug_Arrow_Signal_" + TimeToString(TimeCurrent()) + (m_is_test ? "_Test" : "");
            if(ObjectCreate(0, arrow_name, m_parent_mother.GetDirection() == LONG ? OBJ_ARROW_UP : OBJ_ARROW_DOWN, 0, TimeCurrent(), current_price))
            {
               ObjectSetInteger(0, arrow_name, OBJPROP_COLOR, clrGold);
               ArrayResize(m_debug_objects, ArraySize(m_debug_objects) + 1);
               m_debug_objects[ArraySize(m_debug_objects) - 1] = arrow_name;
               CheckObjectExists(arrow_name);
            }
         }
         return true;
      }
      return false;
   }

   bool CheckFailureChild2OnTick(double current_price)
   {
      if(m_parent_mother == NULL) return false;
      double level_0 = m_price0;
      bool fail_condition = (m_parent_mother.GetDirection() == LONG && current_price <= level_0) ||
                            (m_parent_mother.GetDirection() == SHORT && current_price >= level_0);
      if(fail_condition)
      {
         Log("ساختار شکست خورد: لنگرگاه مادر سوراخ شد");
         if(InpVisualDebug)
         {
            string label_name = "Debug_Label_StructureFail_" + TimeToString(TimeCurrent()) + (m_is_test ? "_Test" : "");
            if(ObjectCreate(0, label_name, OBJ_TEXT, 0, TimeCurrent(), current_price))
            {
               ObjectSetString(0, label_name, OBJPROP_TEXT, "ساختار شکست خورد");
               ObjectSetInteger(0, label_name, OBJPROP_COLOR, clrRed);
               ArrayResize(m_debug_objects, ArraySize(m_debug_objects) + 1);
               m_debug_objects[ArraySize(m_debug_objects) - 1] = label_name;
            }
         }
         return true;
      }
      return false;
   }

   bool CheckFailureChild2OnNewBar()
   {
      if(m_parent_mother == NULL) return false;
      if(!m_is_success_child2)
      {
         string temp_levels[];
         int count = StringSplit(InpChild2BreakLevels, StringGetCharacter(",", 0), temp_levels);
         double max_level = StringToDouble(temp_levels[count - 1]);
         double break_level = m_parent_mother.GetPrice100() + (m_parent_mother.GetPrice0() - m_parent_mother.GetPrice100()) * max_level / 100.0;
         bool break_condition = (m_parent_mother.GetDirection() == LONG && iClose(_Symbol, m_timeframe, 1) >= break_level) ||
                                (m_parent_mother.GetDirection() == SHORT && iClose(_Symbol, m_timeframe, 1) <= break_level);
         if(break_condition)
         {
            Log("ساختار شکست خورد: کلوز کندل در سطح ", DoubleToString(max_level, 1), "%");
            if(InpVisualDebug)
            {
               string label_name = "Debug_Label_StructureFail_" + TimeToString(TimeCurrent()) + (m_is_test ? "_Test" : "");
               if(ObjectCreate(0, label_name, OBJ_TEXT, 0, TimeCurrent(), iClose(_Symbol, m_timeframe, 1)))
               {
                  ObjectSetString(0, label_name, OBJPROP_TEXT, "ساختار شکست خورد");
                  ObjectSetInteger(0, label_name, OBJPROP_COLOR, clrRed);
                  ArrayResize(m_debug_objects, ArraySize(m_debug_objects) + 1);
                  m_debug_objects[ArraySize(m_debug_objects) - 1] = label_name;
               }
            }
            return true;
         }
      }
      return false;
   }

   bool CheckChild2Trigger(double current_price)
   {
      if(m_is_success_child2 || m_parent_mother == NULL) return false;
      string temp_levels[];
      int count = StringSplit(InpChild2BreakLevels, StringGetCharacter(",", 0), temp_levels);
      double min_level = StringToDouble(temp_levels[0]);
      double break_level = m_parent_mother.GetPrice100() + (m_parent_mother.GetPrice0() - m_parent_mother.GetPrice100()) * min_level / 100.0;
      bool trigger_condition = (m_parent_mother.GetDirection() == LONG && current_price >= break_level) ||
                               (m_parent_mother.GetDirection() == SHORT && current_price <= break_level);
      if(trigger_condition)
      {
         Log("فرزند دوم (ناموفق) فعال شد");
         return true;
      }
      return false;
   }

   bool IsFixed() { return m_is_fixed; }
   bool IsSuccessChild2() { return m_is_success_child2; }
};

//+------------------------------------------------------------------+
//| کلاس CFamily: مدیریت ساختار فیبوناچی                          |
//+------------------------------------------------------------------+
class CFamily
{
private:
   string m_id;
   ENUM_STRUCTURE_STATE m_state;
   ENUM_DIRECTION m_direction;
   CMotherFibo* m_mother;
   CChildFibo* m_child1;
   CChildFibo* m_child2;
   CFractalFinder m_fractal_finder;
   bool m_is_test;

   void Log(string message)
   {
      if(InpEnableLog) Print(TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES | TIME_SECONDS), ": ", m_id, ": ", message);
   }

public:
   CFamily(string id, ENUM_DIRECTION direction, bool is_test, ENUM_TIMEFRAMES timeframe)
   {
      m_id = id; m_state = SEARCHING; m_direction = direction; m_is_test = is_test;
      m_mother = NULL; m_child1 = NULL; m_child2 = NULL;
      m_fractal_finder = CFractalFinder(timeframe);
   }

   bool Initialize()
   {
      SFractal fractal;
      if(m_direction == LONG)
         m_fractal_finder.FindRecentHigh(TimeCurrent(), InpFractalLookback, InpFractalPeers, fractal);
      else
         m_fractal_finder.FindRecentLow(TimeCurrent(), InpFractalLookback, InpFractalPeers, fractal);
      if(fractal.price == 0.0 || fractal.time == 0)
      {
         Log("فراکتال یافت نشد");
         return false;
      }
      m_mother = new CMotherFibo(m_id + "_Mother", InpMotherColor, InpMotherLevels, m_direction, m_is_test, InpTimeframe);
      if(m_mother == NULL || !m_mother.Initialize(fractal, TimeCurrent()))
      {
         Log("خطا: نمی‌توان مادر را ایجاد کرد");
         delete m_mother; m_mother = NULL;
         return false;
      }
      m_state = MOTHER_ACTIVE;
      Log("ساختار در حالت مادر فعال");
      return true;
   }

   bool UpdateOnTick(double current_price, datetime current_time)
   {
      if(m_state == SEARCHING) return Initialize();
      else if(m_state == MOTHER_ACTIVE)
      {
         if(m_mother != NULL && m_mother.CheckStructureFailure(current_price))
         {
            m_state = FAILED; Log("ساختار شکست خورد");
            return false;
         }
         if(m_mother != NULL && !m_mother.UpdateOnTick(current_time)) return false;
         if(m_mother != NULL && InpMotherFixMode == PRICE_CROSS && m_mother.CheckFixingPriceCross(current_price))
         {
            m_child1 = new CChildFibo(m_id + "_Child1", InpChild1Color, InpChildLevels, m_mother, false, m_is_test, InpTimeframe);
            if(m_child1 == NULL || !m_child1.Initialize(current_time))
            {
               Log("خطا: نمی‌توان فرزند اول را ایجاد کرد");
               delete m_child1; m_child1 = NULL; m_state = FAILED;
               return false;
            }
            m_state = CHILD1_ACTIVE;
            Log("ساختار به فرزند اول فعال تغییر کرد");
         }
      }
      else if(m_state == CHILD1_ACTIVE)
      {
         if(m_mother != NULL && m_mother.CheckStructureFailure(current_price))
         {
            m_state = FAILED; Log("ساختار شکست خورد");
            return false;
         }
         if(m_child1 != NULL && m_child1.CheckFailure(current_price))
         {
            m_child1.Delete();
            delete m_child1; // حذف آبجکت از حافظه
            m_child1 = NULL; // خنثی کردن پوینتر
            m_child2 = new CChildFibo(m_id + "_FailureChild2", InpChild2Color, InpChildLevels, m_mother, false, m_is_test, InpTimeframe);
            if(m_child2 == NULL || !m_child2.Initialize(current_time))
            {
               Log("خطا: نمی‌توان فرزند دوم (ناموفق) را ایجاد کرد");
               delete m_child2; m_child2 = NULL; m_state = FAILED;
               return false;
            }
            m_state = CHILD2_ACTIVE;
            Log("فرزند اول شکست خورد، ساختار به فرزند دوم (ناموفق) تغییر کرد");
         }
         else if(m_child1 != NULL && m_child1.UpdateOnTick(current_time))
         {
            if(m_child1.IsFixed() && m_child1.CheckChild1TriggerChild2(current_price))
            {
               m_child2 = new CChildFibo(m_id + "_SuccessChild2", InpChild2Color, InpChildLevels, m_mother, true, m_is_test, InpTimeframe);
               if(m_child2 == NULL || !m_child2.Initialize(current_time))
               {
                  Log("خطا: نمی‌توان فرزند دوم (موفق) را ایجاد کرد");
                  delete m_child2; m_child2 = NULL; m_state = FAILED;
                  return false;
               }
               m_state = CHILD2_ACTIVE;
               Log("فرزند اول فیکس شد، ساختار به فرزند دوم (موفق) تغییر کرد");
            }
            else m_child1.CheckFixing(current_price);
         }
      }
      else if(m_state == CHILD2_ACTIVE)
      {
         if(m_mother != NULL && m_mother.CheckStructureFailure(current_price))
         {
            m_state = FAILED; Log("ساختار شکست خورد");
            return false;
         }
         if(m_child2 != NULL && m_child2.CheckFailureChild2OnTick(current_price))
         {
            m_state = FAILED; Log("ساختار شکست خورد");
            return false;
         }
         if(m_child2 != NULL && m_child2.UpdateOnTick(current_time))
         {
            if(m_child2.IsSuccessChild2() && m_child2.CheckSuccessChild2(current_price))
            {
               m_state = COMPLETED; Log("ساختار کامل شد");
               return true;
            }
            else if(!m_child2.IsSuccessChild2() && m_child2.CheckChild2Trigger(current_price))
            {
               m_child2.Delete();
               delete m_child2; // حذف آبجکت از حافظه
               m_child2 = NULL; // خنثی کردن پوینتر
               m_child2 = new CChildFibo(m_id + "_FailureChild2", InpChild2Color, InpChildLevels, m_mother, false, m_is_test, InpTimeframe);
               if(m_child2 == NULL || !m_child2.Initialize(current_time))
               {
                  Log("خطا: نمی‌توان فرزند دوم (ناموفق) را ایجاد کرد");
                  delete m_child2; m_child2 = NULL; m_state = FAILED;
                  return false;
               }
               Log("فرزند دوم (ناموفق) فعال شد");
            }
         }
      }
      return true;
   }

   bool UpdateOnNewBar()
   {
      if(m_state == MOTHER_ACTIVE)
      {
         if(m_mother != NULL && InpMotherFixMode == CANDLE_CLOSE && m_mother.CheckFixingCandleClose())
         {
            m_child1 = new CChildFibo(m_id + "_Child1", InpChild1Color, InpChildLevels, m_mother, false, m_is_test, InpTimeframe);
            if(m_child1 == NULL || !m_child1.Initialize(TimeCurrent()))
            {
               Log("خطا: نمی‌توان فرزند اول را ایجاد کرد");
               delete m_child1; m_child1 = NULL; m_state = FAILED;
               return false;
            }
            m_state = CHILD1_ACTIVE;
            Log("ساختار به فرزند اول فعال تغییر کرد");
         }
      }
      else if(m_state == CHILD2_ACTIVE)
      {
         if(m_child2 != NULL && m_child2.CheckFailureChild2OnNewBar())
         {
            m_state = FAILED; Log("ساختار شکست خورد");
            return false;
         }
      }
      return true;
   }

   SSignal GetSignal()
   {
      SSignal signal = {"", ""};
      if(m_state == CHILD2_ACTIVE && m_child2 != NULL)
      {
         string temp_levels[];
         int count = StringSplit(InpGoldenZone, StringGetCharacter(",", 0), temp_levels);
         double min_level = StringToDouble(temp_levels[0]) / 100.0;
         double max_level = StringToDouble(temp_levels[1]) / 100.0;
         double level_min = m_child2.GetPrice100() + (m_child2.GetPrice0() - m_child2.GetPrice100()) * min_level;
         double level_max = m_child2.GetPrice100() + (m_child2.GetPrice0() - m_child2.GetPrice100()) * max_level;
         double current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         bool in_golden_zone = (m_direction == LONG && current_price >= level_min && current_price <= level_max) ||
                               (m_direction == SHORT && current_price <= level_min && current_price >= level_max);
         if(in_golden_zone)
         {
            signal.type = m_direction == LONG ? "Buy" : "Sell";
            signal.id = m_id + "_" + TimeToString(TimeCurrent()) + "_" + (m_direction == LONG ? "Long" : "Short") + "_" + (m_child2.IsSuccessChild2() ? "Success" : "Failure");
            Log("سیگنال ", signal.type, ": ID=", signal.id);
            if(InpVisualDebug)
            {
               string arrow_name = "Debug_Arrow_Signal_" + TimeToString(TimeCurrent()) + (m_is_test ? "_Test" : "");
               if(ObjectCreate(0, arrow_name, m_direction == LONG ? OBJ_ARROW_UP : OBJ_ARROW_DOWN, 0, TimeCurrent(), current_price))
               {
                  ObjectSetInteger(0, arrow_name, OBJPROP_COLOR, clrGold);
                  ArrayResize(m_debug_objects, ArraySize(m_debug_objects) + 1);
                  m_debug_objects[ArraySize(m_debug_objects) - 1] = arrow_name;
                  CheckObjectExists(arrow_name);
               }
            }
         }
      }
      return signal;
   }

   bool IsActive() { return m_state != COMPLETED && m_state != FAILED; }
   void Destroy()
   {
      if(m_child2 != NULL) { m_child2.Delete(); delete m_child2; m_child2 = NULL; }
      if(m_child1 != NULL) { m_child1.Delete(); delete m_child1; m_child1 = NULL; }
      if(m_mother != NULL) { m_mother.Delete(); delete m_mother; m_mother = NULL; }
      m_state = FAILED;
   }

   ENUM_STRUCTURE_STATE GetState() { return m_state; }
};

//+------------------------------------------------------------------+
//| کلاس CStructureManager: مدیریت تمام ساختارها                   |
//+------------------------------------------------------------------+
class CStructureManager
{
private:
   CFamily* m_families[];
   CPanel* m_panel;
   CTestPanel* m_test_panel;
   bool m_is_test_mode;
   string m_current_command;
   ENUM_TIMEFRAMES m_timeframe;

   bool IsBusy() { return ArraySize(m_families) >= InpMaxFamilies; }

   void Log(string message, bool is_error = false)
   {
      if(InpEnableLog)
      {
         string log_message = TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES | TIME_SECONDS) + ": " + message;
         Print(log_message);
         int handle = FileOpen(InpLogFilePath, FILE_WRITE | FILE_TXT | FILE_COMMON);
         if(handle != INVALID_HANDLE)
         {
            FileSeek(handle, 0, SEEK_END);
            FileWrite(handle, log_message);
            FileClose(handle);
         }
         if(is_error && m_panel != NULL) m_panel.UpdateStatus(message, true);
      }
   }

   void CleanUpFamilies()
   {
      for(int i = ArraySize(m_families) - 1; i >= 0; i--)
         if(m_families[i] == NULL) ArrayRemove(m_families, i, 1);
   }

public:
   CStructureManager()
   {
      ArrayResize(m_families, 0); m_panel = NULL; m_test_panel = NULL;
      m_is_test_mode = false; m_current_command = "";
      m_timeframe = InpTimeframe == PERIOD_CURRENT ? _Period : InpTimeframe;
   }

   bool HFiboOnInit()
   {
      ChartSetInteger(0, CHART_EVENT_OBJECT_CREATE, true);
      ChartSetInteger(0, CHART_EVENT_MOUSE_MOVE, true);
      if(InpShowPanel)
      {
         m_panel = new CPanel("HipoFibo_Panel", InpPanelCorner, InpPanelOffsetX, InpPanelOffsetY);
         if(m_panel == NULL || !m_panel.Create())
         {
            Log("خطا: نمی‌توان پنل اصلی را ایجاد کرد", true);
            return false;
         }
      }
      if(InpTestMode) EnableTestMode(true);
      Log("کتابخانه HipoFibonacci راه‌اندازی شد");
      return true;
   }

   void HFiboOnDeinit(const int reason)
   {
      for(int i = 0; i < ArraySize(m_families); i++)
         if(m_families[i] != NULL) { m_families[i].Destroy(); delete m_families[i]; }
      ArrayResize(m_families, 0);
      if(m_panel != NULL) { m_panel.Destroy(); delete m_panel; m_panel = NULL; }
      if(m_test_panel != NULL) { m_test_panel.Destroy(); delete m_test_panel; m_test_panel = NULL; }
      Log("کتابخانه HipoFibonacci متوقف شد. دلیل: ", reason);
   }

   void HFiboOnTick()
   {
      double current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      datetime current_time = TimeCurrent();
      string status = "";
      for(int i = ArraySize(m_families) - 1; i >= 0; i--)
      {
         if(m_families[i] != NULL && !m_families[i].UpdateOnTick(current_price, current_time))
         {
            m_families[i].Destroy();
            delete m_families[i]; m_families[i] = NULL;
         }
         else if(m_families[i] != NULL)
         {
            ENUM_STRUCTURE_STATE state = m_families[i].GetState();
            switch(state)
            {
               case SEARCHING: status = "در حال جستجوی فراکتال..."; break;
               case MOTHER_ACTIVE: status = "مادر فعال، در انتظار فیکس شدن..."; break;
               case CHILD1_ACTIVE: status = "فرزند اول فعال، در انتظار فیکس یا شکست..."; break;
               case CHILD2_ACTIVE: status = "فرزند دوم فعال، در انتظار سیگنال یا شکست..."; break;
               case COMPLETED: status = "ساختار کامل شد (سیگنال صادر شد)"; break;
               case FAILED: status = "ساختار شکست خورد"; break;
            }
         }
      }
      CleanUpFamilies();
      if(m_panel != NULL)
      {
         if(status == "") status = "در حال انتظار";
         status += "، ساختارهای فعال: " + IntegerToString(ArraySize(m_families));
         m_panel.UpdateStatus(status);
         if(ArraySize(m_families) == 0 && m_panel.ShouldResetStatus())
            m_panel.ResetStatus();
      }
   }

   void HFiboOnNewBar()
   {
      for(int i = ArraySize(m_families) - 1; i >= 0; i--)
         if(m_families[i] != NULL && !m_families[i].UpdateOnNewBar())
         {
            m_families[i].Destroy();
            delete m_families[i]; m_families[i] = NULL;
         }
      CleanUpFamilies();
   }

   bool CreateNewStructure(ENUM_DIRECTION direction)
   {
      if(IsBusy())
      {
         Log("سیستم مشغول است، دستور نادیده گرفته شد: جهت=", (direction == LONG ? "Long" : "Short"), true);
         return false;
      }
      string id = "HFibo_" + TimeToString(TimeCurrent()) + "_" + (direction == LONG ? "Long" : "Short");
      CFamily* family = new CFamily(id, direction, m_is_test_mode, m_timeframe);
      if(family == NULL || !family.Initialize())
      {
         Log("خطا: نمی‌توان ساختار جدید را ایجاد کرد", true);
         delete family;
         return false;
      }
      ArrayResize(m_families, ArraySize(m_families) + 1);
      m_families[ArraySize(m_families) - 1] = family;
      Log("ساختار جدید ایجاد شد: ID=", id);
      if(m_panel != NULL) m_panel.UpdateCommand(direction == LONG ? "Start Long" : "Start Short");
      return true;
   }

   bool HFiboStartStructure(ENUM_DIRECTION direction)
   {
      if(m_is_test_mode)
      {
         Log("حالت تست فعال است، دستور StartStructure نادیده گرفته شد", true);
         return false;
      }
      return CreateNewStructure(direction);
   }

   void HFiboOnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
   {
      if(!m_is_test_mode || m_test_panel == NULL) return;
      string command = "";
      if(id == CHARTEVENT_OBJECT_CLICK && m_test_panel.OnButtonClick(sparam, command))
      {
         if(command == "StartLong")
         {
            if(CreateNewStructure(LONG)) m_test_panel.UpdateSignal("", "");
            else m_panel.UpdateTestStatus("سیستم مشغول است");
         }
         else if(command == "StartShort")
         {
            if(CreateNewStructure(SHORT)) m_test_panel.UpdateSignal("", "");
            else m_panel.UpdateTestStatus("سیستم مشغول است");
         }
         else if(command == "Stop")
         {
            for(int i = ArraySize(m_families) - 1; i >= 0; i--)
               if(m_families[i] != NULL)
               {
                  m_families[i].Destroy();
                  delete m_families[i]; m_families[i] = NULL;
               }
            CleanUpFamilies();
            m_panel.UpdateStatus("ساختارها متوقف شدند");
            m_test_panel.UpdateSignal("", "");
            Log("تمام ساختارها متوقف شدند");
         }
      }
   }

   SSignal HFiboCheckSignal()
   {
      SSignal signal = {"", ""};
      for(int i = 0; i < ArraySize(m_families); i++)
         if(m_families[i] != NULL)
         {
            signal = m_families[i].GetSignal();
            if(signal.type != "" && m_test_panel != NULL)
               m_test_panel.UpdateSignal(signal.type, signal.id);
         }
      return signal;
   }

   bool HFiboAcknowledgeSignal(string id)
   {
      for(int i = ArraySize(m_families) - 1; i >= 0; i--)
         if(m_families[i] != NULL && StringFind(m_families[i].GetSignal().id, id) >= 0)
         {
            m_families[i].Destroy();
            delete m_families[i]; m_families[i] = NULL;
            Log("سیگنال تأیید شد: ID=", id);
            CleanUpFamilies();
            return true;
         }
      Log("سیگنال با ID=", id, " یافت نشد");
      return false;
   }

   void EnableTestMode(bool enable)
   {
      m_is_test_mode = enable;
      if(enable && m_test_panel == NULL)
      {
         m_test_panel = new CTestPanel("HipoFibo_TestPanel", InpTestPanelCorner, InpTestPanelOffsetX, InpTestPanelOffsetY,
                                       InpTestPanelButtonColorLong, InpTestPanelButtonColorShort, InpTestPanelButtonColorStop, InpTestPanelBgColor);
         if(m_test_panel == NULL || !m_test_panel.Create())
         {
            Log("خطا: نمی‌توان پنل تست را ایجاد کرد", true);
            delete m_test_panel; m_test_panel = NULL;
            m_is_test_mode = false;
         }
         else Log("حالت تست فعال شد");
      }
      else if(!enable && m_test_panel != NULL)
      {
         m_test_panel.Destroy();
         delete m_test_panel; m_test_panel = NULL;
         Log("حالت تست غیرفعال شد");
      }
   }
};

//+------------------------------------------------------------------+
//| متغیرهای سراسری و توابع رابط                                  |
//+------------------------------------------------------------------+
CStructureManager g_manager;

int OnInit() { return g_manager.HFiboOnInit() ? INIT_SUCCEEDED : INIT_FAILED; }
void OnDeinit(const int reason) { g_manager.HFiboOnDeinit(reason); }
void OnTick() { g_manager.HFiboOnTick(); }
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam) { g_manager.HFiboOnChartEvent(id, lparam, dparam, sparam); }
void OnTimer() {}
