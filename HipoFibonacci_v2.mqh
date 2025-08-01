//+------------------------------------------------------------------+
//|                                              HipoFibonacci.mqh   |
//|                              محصولی از: Hipo Algorithm           |
//|                              نسخه: 2.0.0                          |
//|                              تاریخ: 2025/07/27                   |
//| کتابخانه فیبوناچی برای پروژه HipoFino                          |
//+------------------------------------------------------------------+

#property copyright "Hipo Algorithm"
#property link      "https://hipoalgorithm.com"
#property version   "2.0.0"

#ifndef HIPO_FIBONACCI_MQH
#define HIPO_FIBONACCI_MQH

//+------------------------------------------------------------------+
//| تابع عمومی برای بررسی وجود شیء                                  |
//+------------------------------------------------------------------+
bool CheckObjectExists(string name)
{
   for(int i = 0; i < 3; i++)
   {
      if(ObjectFind(0, name) >= 0) return true;
      Sleep(50);
   }
   Print("خطا: عدم رندر شیء " + name);
   return false;
}

//+------------------------------------------------------------------+
//| تابع پاک‌سازی اشیاء گرافیکی قدیمی                             |
//+------------------------------------------------------------------+
void ClearDebugObjects(bool is_test)
{
   string prefix = is_test ? "_Test" : "";
   for(int i = ObjectsTotal(0, -1, -1) - 1; i >= 0; i--)
   {
      string obj_name = ObjectName(0, i);
      if(StringFind(obj_name, "Debug_") >= 0 && StringFind(obj_name, prefix) >= 0)
         ObjectDelete(0, obj_name);
   }
}

//+------------------------------------------------------------------+
//| ورودی‌های کتابخانه                                              |
//+------------------------------------------------------------------+


enum ENUM_STRUCTURE_START_MODE
{
   USE_LAST_BREAK,      // استفاده از آخرین شکست ثبت شده
   WAIT_FOR_NEW_BREAK   // انتظار برای شکست جدید بعد از دستور
};
input ENUM_STRUCTURE_START_MODE InpStructureStartMode = USE_LAST_BREAK; // حالت شروع ساختار
//^^^^^^^^^^ پایان بخش جدید ^^^^^^^^^^


input group "تنظیمات فراکتال"
input int InpFractalLookback = 288;       // حداکثر تعداد کندل برای جستجوی فراکتال (حداقل 10)
input int InpFractalPeers = 3;            // تعداد کندل‌های چپ/راست برای فراکتال (حداقل 1)
input ENUM_TIMEFRAMES InpFractalTimeframe = PERIOD_CURRENT; // تایم‌فریم تحلیل فرکتال

input group "شکست ساختار اولیه (برای مادر)"
enum ENUM_FRACTAL_BREAK_MODE
{
   SIMPLE_PRICE_CROSS,       // عبور لحظه‌ای قیمت
   FRACTAL_CANDLE_CLOSE,     // کلوز کندل
   FRACTAL_CONFIRMED_BREAK   // شکست تأییدشده
};
input ENUM_FRACTAL_BREAK_MODE InpFractalBreakMode = FRACTAL_CANDLE_CLOSE; // روش شکست فرکتال
input int InpMaxBreakoutCandles = 3; // حداکثر کندل‌های فرصت برای تأیید شکست

input group "فیکس شدن مادر"
enum ENUM_FIX_MODE
{
   FIX_PRICE_CROSS,  // عبور لحظه‌ای قیمت
   FIX_CANDLE_CLOSE  // کلوز کندل
};
input ENUM_FIX_MODE InpMotherFixMode = FIX_PRICE_CROSS; // حالت فیکس شدن مادر

input group "تخریب ساختار"
enum ENUM_STRUCTURE_BREAK_MODE
{
   STRUCTURE_PRICE_CROSS,  // عبور لحظه‌ای قیمت
   STRUCTURE_CANDLE_CLOSE  // کلوز کندل
};
input ENUM_STRUCTURE_BREAK_MODE InpStructureBreakMode = STRUCTURE_PRICE_CROSS; // حالت تخریب ساختار

input group "شکست فرزند اول"
enum ENUM_CHILD_BREAK_MODE
{
   CHILD_PRICE_CROSS,      // عبور ساده قیمت
   CHILD_CONFIRMED_BREAK   // شکست تأییدشده
};
input ENUM_CHILD_BREAK_MODE InpChildBreakMode = CHILD_CONFIRMED_BREAK; // حالت شکست سطح 100% فرزند

input group "سطوح فیبوناچی"
input string InpMotherLevels = "0,38,50,68,100,150,200,250"; // سطوح فیبو مادر
input string InpChildLevels = "0,38,50,68,100,150,200,250";  // سطوح فیبو فرزندان
input string InpGoldenZone = "38,50"; // ناحیه طلایی برای سیگنال

input group "رنگ‌بندی اشیاء"
input color InpMotherColor = clrWhite;    // رنگ فیبوناچی مادر
input color InpChild1Color = clrMagenta;  // رنگ فیبوناچی فرزند اول
input color InpChild2Color = clrGreen;    // رنگ فیبوناچی فرزند دوم

input group "تنظیمات پنل اصلی"
input bool InpShowPanelEa = true; // نمایش پنل اصلی اطلاعاتی
input ENUM_BASE_CORNER InpPanelCorner = CORNER_LEFT_UPPER; // گوشه پنل اصلی
input int InpPanelOffsetX = 10; // فاصله افقی پنل اصلی
input int InpPanelOffsetY = 136; // فاصله عمودی پنل اصلی

input group "تنظیمات حالت تست"
input bool InpTestMode = false; // فعال‌سازی حالت تست داخلی
input ENUM_BASE_CORNER InpTestPanelCorner = CORNER_RIGHT_UPPER; // گوشه پنل تست
input int InpTestPanelOffsetX = 153; // فاصله افقی پنل تست
input int InpTestPanelOffsetY = 39; // فاصله عمودی پنل تست
input color InpTestPanelButtonColorLong = clrGreen; // رنگ دکمه Start Long
input color InpTestPanelButtonColorShort = clrRed; // رنگ دکمه Start Short
input color InpTestPanelButtonColorStop = clrGray; // رنگ دکمه Stop
input color InpTestPanelBgColor = clrDarkGray; // رنگ پس‌زمینه پنل تست

input group "تنظیمات دیباگ"
input bool InpVisualDebug = false; // فعال‌سازی حالت تست بصری

input group "تنظیمات لاگ"
input bool InpEnableLog = false; // فعال‌سازی لاگ‌گیری
input string InpLogFilePath = "HipoFibonacci_Log.txt"; // مسیر فایل لاگ
input int InpMaxFamilies = 1; // حداکثر تعداد ساختارهای فعال (فقط 1)

//+------------------------------------------------------------------+
//| ساختارها و ثابت‌ها                                              |
//+------------------------------------------------------------------+
enum ENUM_STRUCTURE_STATE
{
   SEARCHING,      // در حال جستجوی فراکتال
   MOTHER_ACTIVE,  // مادر فعال
   CHILD1_ACTIVE,  // فرزند اول فعال
   CHILD2_ACTIVE,  // فرزند دوم فعال
   COMPLETED,      // ساختار کامل شده
   FAILED          // ساختار شکست خورده
};

enum ENUM_DIRECTION
{
   DIRECTION_NONE, // حالت خنثی یا نامشخص
   LONG,           // خرید
   SHORT           // فروش
};
//^^^^^^^^^^ پایان تغییر ^^^^^^^^^^


struct SSignal
{
   string type;    // "Buy" یا "Sell"
   string id;      // شناسه منحصربه‌فرد
};

struct SFractal
{
   double price;
   datetime time;
};

struct SBrokenFractal
{
   datetime time;          // زمان فرکتال
   double price;           // قیمت فرکتال
   ENUM_DIRECTION direction; // جهت فرکتال (LONG/SHORT)
   datetime break_time;    // زمان شکست
   bool is_bos;            // true: BOS, false: CHOCH
};

struct SPendingBreakout
{
   datetime time;          // زمان فرکتال
   double price;           // قیمت فرکتال
   ENUM_DIRECTION direction; // جهت فرکتال
   datetime initial_break_time; // زمان کندل شکست اولیه
   double initial_break_price; // قیمت سقف/کف کندل شکست اولیه
   int candles_left;       // تعداد کندل‌های باقی‌مونده برای تأیید
};

struct SFibonacciEventData
{
   datetime child1_fix_time;          // زمان فیکس شدن فرزند اول
   double child1_fix_price;           // قیمت فیکس شدن فرزند اول
   datetime child1_breakout_time;     // زمان شکست فرزند اول
   double child1_breakout_price;      // قیمت شکست فرزند اول
   string child2_levels_string;       // سطوح فرزند دوم به صورت رشته
};

//+------------------------------------------------------------------+
//| کلاس CFractalFinder: پیدا کردن فراکتال‌ها                      |
//+------------------------------------------------------------------+
class CFractalFinder
{
public:
   bool IsHighFractal(int index, ENUM_TIMEFRAMES timeframe, int peers)
   {
      if(index + peers >= iBars(_Symbol, timeframe)) return false;
      if(index - peers < 0) return false;
      double high = iHigh(_Symbol, timeframe, index);
      for(int i = 1; i <= peers; i++)
      {
         if(iHigh(_Symbol, timeframe, index + i) >= high ||
            iHigh(_Symbol, timeframe, index - i) >= high)
            return false;
      }
      return true;
   }

   bool IsLowFractal(int index, ENUM_TIMEFRAMES timeframe, int peers)
   {
      if(index + peers >= iBars(_Symbol, timeframe)) return false;
      if(index - peers < 0) return false;
      double low = iLow(_Symbol, timeframe, index);
      for(int i = 1; i <= peers; i++)
      {
         if(iLow(_Symbol, timeframe, index + i) <= low ||
            iLow(_Symbol, timeframe, index - i) <= low)
            return false;
      }
      return true;
   }

   void FindRecentHigh(datetime startTime, int lookback, int peers, ENUM_TIMEFRAMES timeframe, SFractal &fractal)
   {
      fractal.price = 0.0;
      fractal.time = 0;
      int startIndex = iBarShift(_Symbol, timeframe, startTime);
      for(int i = startIndex; i <= MathMin(startIndex + lookback, iBars(_Symbol, timeframe) - peers - 1); i++)
      {
         if(IsHighFractal(i, timeframe, peers))
         {
            fractal.price = iHigh(_Symbol, timeframe, i);
            fractal.time = iTime(_Symbol, timeframe, i);
            break;
         }
      }
   }

   void FindRecentLow(datetime startTime, int lookback, int peers, ENUM_TIMEFRAMES timeframe, SFractal &fractal)
   {
      fractal.price = 0.0;
      fractal.time = 0;
      int startIndex = iBarShift(_Symbol, timeframe, startTime);
      for(int i = startIndex; i <= MathMin(startIndex + lookback, iBars(_Symbol, timeframe) - peers - 1); i++)
      {
         if(IsLowFractal(i, timeframe, peers))
         {
            fractal.price = iLow(_Symbol, timeframe, i);
            fractal.time = iTime(_Symbol, timeframe, i);
            break;
         }
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
      ObjectSetInteger(0, name, OBJPROP_YSIZE, 25);
      ObjectSetInteger(0, name, OBJPROP_BGCOLOR, clrGoldenrod);
      ObjectSetInteger(0, name, OBJPROP_ZORDER, 0);
      return CheckObjectExists(name);
   }

public:
   CPanel(string name, ENUM_BASE_CORNER corner, int x, int y)
   {
      m_name = name;
      m_corner = corner;
      m_offset_x = x;
      m_offset_y = y;
      m_flash_counter = 0;
   }

   bool Create()
   {
      return CreateBackground(m_name + "_Bg", m_offset_x, m_offset_y) &&
             CreateHeader(m_name + "_Header", m_offset_x, m_offset_y) &&
             CreateLabel(m_name + "_Title", "Hipo Fibonacci", m_offset_x + 90, m_offset_y + 5, clrWhite, 13, "Calibri Bold") &&
             CreateLabel(m_name + "_Status", "وضعیت: در حال انتظار", m_offset_x + 10, m_offset_y + 35, clrLightGray, 9, "Calibri") &&
             CreateLabel(m_name + "_Command", "دستور: هیچ", m_offset_x + 10, m_offset_y + 65, clrLightGray, 9, "Calibri");
   }

   void UpdateStatus(string status)
   {
      m_flash_counter = (m_flash_counter + 1) % 40;
      color status_color = (m_flash_counter < 20) ? clrLightYellow : clrWhite;
      ObjectSetString(0, m_name + "_Status", OBJPROP_TEXT, "وضعیت: " + status);
      ObjectSetInteger(0, m_name + "_Status", OBJPROP_COLOR, status_color);
   }

   void UpdateCommand(string command)
   {
      ObjectSetString(0, m_name + "_Command", OBJPROP_TEXT, "دستور: " + command);
   }

   void UpdateTestStatus(string status)
   {
      m_flash_counter = (m_flash_counter + 1) % 40;
      color status_color = (m_flash_counter < 20) ? clrLightYellow : clrWhite;
      ObjectSetString(0, m_name + "_Status", OBJPROP_TEXT, "حالت تست: " + status);
      ObjectSetInteger(0, m_name + "_Status", OBJPROP_COLOR, status_color);
   }

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
      m_name = name;
      m_corner = corner;
      m_offset_x = x;
      m_offset_y = y;
      m_button_color_long = long_color;
      m_button_color_short = short_color;
      m_button_color_stop = stop_color;
      m_bg_color = bg_color;
   }

   bool Create()
   {
      bool success = CreateBackground(m_name + "_Bg", m_offset_x, m_offset_y) &&
                     CreateButton(m_name + "_StartLong", "Start Long", m_offset_x + 10, m_offset_y + 5, m_button_color_long) &&
                     CreateButton(m_name + "_StartShort", "Start Short", m_offset_x + 110, m_offset_y + 5, m_button_color_short) &&
                     CreateButton(m_name + "_Stop", "Stop", m_offset_x + 210, m_offset_y + 5, m_button_color_stop) &&
                     CreateSignalLabel(m_name + "_Signal", m_offset_x + 10, m_offset_y + 40);
      if(success && InpEnableLog)
         Print("پنل تست با موفقیت ایجاد شد: " + m_name);
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

public:
   CBaseFibo(string name, color clr, string levels, bool is_test)
   {
      m_name = name;
      m_color = clr;
      m_is_test = is_test;
      ArrayFree(m_levels);
      string temp_levels[];
      int count = StringSplit(levels, StringGetCharacter(",", 0), temp_levels);
      ArrayResize(m_levels, count);
      for(int i = 0; i < count; i++)
      {
         double level = StringToDouble(temp_levels[i]);
         if(level < 0) continue;
         m_levels[i] = level;
      }
   }

   virtual bool Draw()
   {
      string obj_name = m_name + (m_is_test ? "_Test" : "");
      ObjectDelete(0, obj_name);
      if(!ObjectCreate(0, obj_name, OBJ_FIBO, 0, m_time0, m_price0, m_time100, m_price100)) return false;
      ObjectSetInteger(0, obj_name, OBJPROP_COLOR, m_color);
      ObjectSetInteger(0, obj_name, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, obj_name, OBJPROP_LEVELS, ArraySize(m_levels));
      for(int i = 0; i < ArraySize(m_levels); i++)
      {
         ObjectSetDouble(0, obj_name, OBJPROP_LEVELVALUE, i, m_levels[i] / 100.0);
         ObjectSetString(0, obj_name, OBJPROP_LEVELTEXT, i, DoubleToString(m_levels[i], 1) + "%");
         ObjectSetInteger(0, obj_name, OBJPROP_LEVELCOLOR, i, m_color);
         ObjectSetInteger(0, obj_name, OBJPROP_LEVELSTYLE, i, STYLE_SOLID);
      }
      ChartRedraw(0);
      Sleep(50);
      return CheckObjectExists(obj_name);
   }

   void Delete()
   {
      string obj_name = m_name + (m_is_test ? "_Test" : "");
      ObjectDelete(0, obj_name);
   }

   void SetPoints(datetime time0, double price0, datetime time100, double price100)
   {
      m_time0 = time0;
      m_price0 = price0;
      m_time100 = time100;
      m_price100 = price100;
   }

   datetime GetTime0() { return m_time0; }
   double GetPrice0() { return m_price0; }
   datetime GetTime100() { return m_time100; }
   double GetPrice100() { return m_price100; }

   double GetLevel(int index) { return index < ArraySize(m_levels) ? m_levels[index] : 0.0; }
   int GetLevelsCount() { return ArraySize(m_levels); }
};

//+------------------------------------------------------------------+
//| کلاس CMotherFibo: فیبوناچی مادر                                |
//+------------------------------------------------------------------+
//vvvvvvvvvv این بلوک کد را به طور کامل جایگزین کلاس CMotherFibo فعلی کن vvvvvvvvvv
class CMotherFibo : public CBaseFibo
{
private:
   ENUM_DIRECTION m_direction;
   void Log(string message)
   {
      if(InpEnableLog)
         CStructureManager::AddLog(message);
   }

public:
   CMotherFibo(string name, color clr, string levels, ENUM_DIRECTION dir, bool is_test)
      : CBaseFibo(name, clr, levels, is_test)
   {
      m_direction = dir;
   }

   bool Initialize(datetime time0, double price0, datetime time100, double price100)
   {
      SetPoints(time0, price0, time100, price100);
      if(Draw())
      {
         Log("مادر متولد شد: صد=" + DoubleToString(m_price100, _Digits) + ", صفر=" + DoubleToString(m_price0, _Digits) + ", زمان=" + TimeToString(m_time0));
         if(InpVisualDebug)
         {
            string arrow_name = "Debug_Arrow_MotherBirth_" + TimeToString(m_time100) + (m_is_test ? "_Test" : "");
            if(ObjectCreate(0, arrow_name, m_direction == LONG ? OBJ_ARROW_UP : OBJ_ARROW_DOWN, 0, m_time100, m_price100))
            {
               ObjectSetInteger(0, arrow_name, OBJPROP_COLOR, m_direction == LONG ? clrSkyBlue : clrOrangeRed);
               CheckObjectExists(arrow_name);
            }
            string label_name = "Debug_Label_MotherBirth_" + TimeToString(m_time100) + (m_is_test ? "_Test" : "");
            if(ObjectCreate(0, label_name, OBJ_TEXT, 0, m_time100, m_price100))
            {
               ObjectSetString(0, label_name, OBJPROP_TEXT, "مادر متولد شد: صد=" + DoubleToString(m_price100, _Digits));
               ObjectSetInteger(0, label_name, OBJPROP_COLOR, clrWhite);
            }
         }
         return true;
      }
      return false;
   }
   
   // این تابع بازنویسی شده تا باگ رسم برعکس فیبوناچی مادر را اصلاح کند
   virtual bool Draw() override
   {
      string obj_name = m_name + (m_is_test ? "_Test" : "");
      ObjectDelete(0, obj_name);

      // نکته کلیدی اینجاست: نقاط 100 و 0 رو جابجا به تابع پاس میدیم تا رسم درست انجام بشه
      if(!ObjectCreate(0, obj_name, OBJ_FIBO, 0, m_time100, m_price100, m_time0, m_price0))
      {
         Print("خطا در ایجاد شیء فیبوناچی مادر: ", obj_name);
         return false;
      }

      ObjectSetInteger(0, obj_name, OBJPROP_COLOR, m_color);
      ObjectSetInteger(0, obj_name, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, obj_name, OBJPROP_LEVELS, ArraySize(m_levels));
      for(int i = 0; i < ArraySize(m_levels); i++)
      {
         ObjectSetDouble(0, obj_name, OBJPROP_LEVELVALUE, i, m_levels[i] / 100.0);
         ObjectSetString(0, obj_name, OBJPROP_LEVELTEXT, i, DoubleToString(m_levels[i], 1) + "%");
         ObjectSetInteger(0, obj_name, OBJPROP_LEVELCOLOR, i, m_color);
         ObjectSetInteger(0, obj_name, OBJPROP_LEVELSTYLE, i, STYLE_SOLID);
      }
      ChartRedraw(0);
      Sleep(50);
      return CheckObjectExists(obj_name);
   }

   ENUM_DIRECTION GetDirection() { return m_direction; }
};
//^^^^^^^^^^ پایان بلوک جایگزینی ^^^^^^^^^^


//+------------------------------------------------------------------+
//| کلاس CChildFibo: فیبوناچی فرزند                                |
//+------------------------------------------------------------------+
class CChildFibo : public CBaseFibo
{
private:
   bool m_is_fixed;
   bool m_is_success_child2;
   CMotherFibo* m_parent_mother;
   ENUM_DIRECTION m_direction;
   bool m_breakout_triggered;
   datetime m_breakout_candle_time;
   double m_breakout_candle_high, m_breakout_candle_low;
   int m_breakout_candle_count;
   datetime m_fixation_time, m_breakout_time;
   double m_fixation_price, m_breakout_price;
   string m_golden_zone_name;

   void Log(string message)
   {
      if(InpEnableLog)
         CStructureManager::AddLog(message);
   }

   bool DrawGoldenZone()
   {
      if(!m_is_success_child2) return true;
      string rect_name = m_golden_zone_name + (m_is_test ? "_Test" : "");
      ObjectDelete(0, rect_name);
      string temp_levels[];
      int count = StringSplit(InpGoldenZone, StringGetCharacter(",", 0), temp_levels);
      if(count < 2)
      {
         Log("خطا: InpGoldenZone باید حداقل دو سطح داشته باشد");
         return false;
      }
      double level_1 = StringToDouble(temp_levels[0]) / 100.0;
      double level_2 = StringToDouble(temp_levels[1]) / 100.0;
      double price_level_1 = m_price100 + (m_price0 - m_price100) * level_1;
      double price_level_2 = m_price100 + (m_price0 - m_price100) * level_2;
      double zone_lower = MathMin(price_level_1, price_level_2);
      double zone_upper = MathMax(price_level_1, price_level_2);
      datetime right_edge = iTime(_Symbol, _Period, 0) + PeriodSeconds(_Period) * 100;
      if(!ObjectCreate(0, rect_name, OBJ_RECTANGLE, 0, m_time100, zone_lower, right_edge, zone_upper)) return false;
      ObjectSetInteger(0, rect_name, OBJPROP_COLOR, clrGoldenrod);
      ObjectSetInteger(0, rect_name, OBJPROP_BGCOLOR, clrGoldenrod);
      ObjectSetInteger(0, rect_name, OBJPROP_FILL, true);
      ObjectSetInteger(0, rect_name, OBJPROP_ZORDER, -1);
      CheckObjectExists(rect_name);
      Log("مستطیل زون طلایی رسم شد: از " + TimeToString(m_time100) + " تا لبه چارت");
      return true;
   }

public:
   CChildFibo(string name, color clr, string levels, CMotherFibo* mother, bool is_success_child2, bool is_test)
      : CBaseFibo(name, clr, levels, is_test)
   {
      m_is_fixed = false;
      m_is_success_child2 = is_success_child2;
      m_parent_mother = mother;
      m_direction = mother != NULL ? mother.GetDirection() : LONG;
      m_breakout_triggered = false;
      m_breakout_candle_time = 0;
      m_breakout_candle_high = 0.0;
      m_breakout_candle_low = 0.0;
      m_breakout_candle_count = 0;
      m_fixation_time = 0;
      m_fixation_price = 0.0;
      m_breakout_time = 0;
      m_breakout_price = 0.0;
      m_golden_zone_name = name + "_GoldenZone";
   }

   bool Initialize(datetime current_time)
   {
      if(m_parent_mother == NULL) return false;
      m_time0 = m_parent_mother.GetTime0();
      m_price0 = m_parent_mother.GetPrice0();
      if(m_direction == LONG)
      {
         m_price100 = iHigh(_Symbol, _Period, iBarShift(_Symbol, _Period, current_time));
         for(int i = iBarShift(_Symbol, _Period, m_time0); i >= iBarShift(_Symbol, _Period, current_time); i--)
            m_price100 = MathMax(m_price100, iHigh(_Symbol, _Period, i));
      }
      else
      {
         m_price100 = iLow(_Symbol, _Period, iBarShift(_Symbol, _Period, current_time));
         for(int i = iBarShift(_Symbol, _Period, m_time0); i >= iBarShift(_Symbol, _Period, current_time); i--)
            m_price100 = MathMin(m_price100, iLow(_Symbol, _Period, i));
      }
      m_time100 = current_time;
      if(Draw())
      {
         Log("فرزند " + (StringFind(m_name, "Child1") >= 0 ? "اول" : (m_is_success_child2 ? "دوم (پیچیده)" : "دوم (ساده)")) +
             " متولد شد: صد=" + DoubleToString(m_price100, _Digits) + ", صفر=" + DoubleToString(m_price0, _Digits));
         if(m_is_success_child2) DrawGoldenZone();
         if(InpVisualDebug)
         {
            string arrow_name = "Debug_Arrow_" + (StringFind(m_name, "Child1") >= 0 ? "Child1Birth_" : "Child2Birth_") +
                                TimeToString(m_time100) + (m_is_test ? "_Test" : "");
            if(ObjectCreate(0, arrow_name, m_direction == LONG ? OBJ_ARROW_UP : OBJ_ARROW_DOWN, 0, m_time100, m_price100))
            {
               ObjectSetInteger(0, arrow_name, OBJPROP_COLOR, StringFind(m_name, "Child1") >= 0 ? (m_direction == LONG ? clrCyan : clrPink) :
                                                               (m_direction == LONG ? clrDarkGreen : clrDarkRed));
               CheckObjectExists(arrow_name);
            }
         }
         return true;
      }
      return false;
   }

   bool UpdateOnTick(datetime new_time)
   {
      if(m_is_fixed || m_parent_mother == NULL) return true;
      for(int i = ObjectsTotal(0, -1, OBJ_HLINE) - 1; i >= 0; i--)
      {
         string obj_name = ObjectName(0, i);
         if(StringFind(obj_name, "Debug_HLine_" + m_name) >= 0)
            ObjectDelete(0, obj_name);
      }
      double old_price100 = m_price100;
      if(m_direction == LONG)
         m_price100 = MathMax(m_price100, iHigh(_Symbol, _Period, iBarShift(_Symbol, _Period, new_time)));
      else
         m_price100 = MathMin(m_price100, iLow(_Symbol, _Period, iBarShift(_Symbol, _Period, new_time)));
      if(m_price100 != old_price100)
      {
         m_time100 = new_time;
         string obj_name = m_name + (m_is_test ? "_Test" : "");
         if(CheckObjectExists(obj_name) && ObjectMove(0, obj_name, 0, m_time100, m_price100))
         {
            Log("صد فرزند " + (StringFind(m_name, "Child1") >= 0 ? "اول" : (m_is_success_child2 ? "دوم (پیچیده)" : "دوم (ساده)")) +
                " آپدیت شد: صد=" + DoubleToString(m_price100, _Digits));
            if(InpVisualDebug)
            {
               string line_name = "Debug_HLine_" + (StringFind(m_name, "Child1") >= 0 ? "Child1Hundred_" : "Child2Hundred_") +
                                  TimeToString(new_time) + (m_is_test ? "_Test" : "");
               if(ObjectCreate(0, line_name, OBJ_HLINE, 0, 0, m_price100))
               {
                  ObjectSetInteger(0, line_name, OBJPROP_COLOR, clrLightGray);
                  ObjectSetInteger(0, line_name, OBJPROP_STYLE, STYLE_DOT);
                  CheckObjectExists(line_name);
               }
            }
            return Draw();
         }
         return false;
      }
      return true;
   }

   bool CheckFixing(double current_price)
   {
      if(m_is_fixed || StringFind(m_name, "Child2") >= 0 || m_parent_mother == NULL) return false;
      double level_50 = m_price100 + (m_price0 - m_price100) * 0.5;
      bool fix_condition = (m_direction == LONG && current_price <= level_50) ||
                           (m_direction == SHORT && current_price >= level_50);
      if(fix_condition)
      {
         m_is_fixed = true;
         m_fixation_time = TimeCurrent();
         m_fixation_price = current_price;
         Log("فرزند اول فیکس شد: صد=" + DoubleToString(m_price100, _Digits));
         if(InpVisualDebug)
         {
            string arrow_name = "Debug_Arrow_Child1Fix_" + TimeToString(TimeCurrent()) + (m_is_test ? "_Test" : "");
            if(ObjectCreate(0, arrow_name, m_direction == LONG ? OBJ_ARROW_DOWN : OBJ_ARROW_UP, 0, TimeCurrent(), current_price))
            {
               ObjectSetInteger(0, arrow_name, OBJPROP_COLOR, m_direction == LONG ? clrGreen : clrRed);
               CheckObjectExists(arrow_name);
            }
            string label_name = "Debug_Label_Child1Fix_" + TimeToString(TimeCurrent()) + (m_is_test ? "_Test" : "");
            if(ObjectCreate(0, label_name, OBJ_TEXT, 0, TimeCurrent(), m_price100))
            {
               ObjectSetString(0, label_name, OBJPROP_TEXT, "فرزند اول فیکس شد: صد=" + DoubleToString(m_price100, _Digits));
               ObjectSetInteger(0, label_name, OBJPROP_COLOR, clrWhite);
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
         bool trigger_condition = (m_direction == LONG && current_price > m_price100) ||
                                 (m_direction == SHORT && current_price < m_price100);
         if(trigger_condition)
         {
            m_breakout_time = TimeCurrent();
            m_breakout_price = current_price;
            Log("فرزند دوم (پیچیده) فعال شد: عبور از صد فرزند اول: قیمت=" + DoubleToString(current_price, _Digits));
            return true;
         }
      }
      return false;
   }

   bool CheckFailure(double current_price)
   {
      if(m_is_fixed || m_parent_mother == NULL) return false;
      if(InpChildBreakMode == CHILD_PRICE_CROSS)
      {
         bool fail_condition = (m_direction == LONG && current_price > m_parent_mother.GetPrice100()) ||
                               (m_direction == SHORT && current_price < m_parent_mother.GetPrice100());
         if(fail_condition)
         {
            Log("فرزند " + (StringFind(m_name, "Child1") >= 0 ? "اول" : (m_is_success_child2 ? "دوم (پیچیده)" : "دوم (ساده)")) +
                " شکست خورد: قیمت=" + DoubleToString(current_price, _Digits));
            if(InpVisualDebug)
            {
               string label_name = "Debug_Label_ChildFail_" + TimeToString(TimeCurrent()) + (m_is_test ? "_Test" : "");
               if(ObjectCreate(0, label_name, OBJ_TEXT, 0, TimeCurrent(), current_price))
               {
                  ObjectSetString(0, label_name, OBJPROP_TEXT, "فرزند " + (StringFind(m_name, "Child1") >= 0 ? "اول" : "دوم") + " شکست خورد");
                  ObjectSetInteger(0, label_name, OBJPROP_COLOR, clrRed);
               }
            }
            return true;
         }
      }
      else if(InpChildBreakMode == CHILD_CONFIRMED_BREAK)
      {
         if(!m_breakout_triggered)
         {
            bool close_condition = (m_direction == LONG && iClose(_Symbol, _Period, 1) >= m_parent_mother.GetPrice100()) ||
                                  (m_direction == SHORT && iClose(_Symbol, _Period, 1) <= m_parent_mother.GetPrice100());
            if(close_condition)
            {
               m_breakout_triggered = true;
               m_breakout_candle_time = iTime(_Symbol, _Period, 1);
               m_breakout_candle_high = iHigh(_Symbol, _Period, 1);
               m_breakout_candle_low = iLow(_Symbol, _Period, 1);
               m_breakout_candle_count = 0;
               Log("شکست اولیه سطح 100% مادر: کلوز=" + DoubleToString(iClose(_Symbol, _Period, 1), _Digits));
            }
         }
         else if(m_breakout_candle_time != 0)
         {
            int shift = iBarShift(_Symbol, _Period, m_breakout_candle_time);
            if(shift <= 0 || m_breakout_candle_count >= InpMaxBreakoutCandles)
            {
               m_breakout_triggered = false;
               m_breakout_candle_time = 0;
               m_breakout_candle_high = 0.0;
               m_breakout_candle_low = 0.0;
               m_breakout_candle_count = 0;
               Log("شکست تأیید نشد: تعداد کندل‌های فرصت به پایان رسید");
               return false;
            }
            m_breakout_candle_count++;
            bool confirm_condition = (m_direction == LONG && iHigh(_Symbol, _Period, 1) >= m_breakout_candle_high) ||
                                    (m_direction == SHORT && iLow(_Symbol, _Period, 1) <= m_breakout_candle_low);
            if(confirm_condition)
            {
               Log("فرزند " + (StringFind(m_name, "Child1") >= 0 ? "اول" : (m_is_success_child2 ? "دوم (پیچیده)" : "دوم (ساده)")) +
                   " شکست خورد (تأییدشده): قیمت=" + DoubleToString(iClose(_Symbol, _Period, 1), _Digits));
               if(InpVisualDebug)
               {
                  string arrow_name = "Debug_Arrow_ChildFail_" + TimeToString(TimeCurrent()) + (m_is_test ? "_Test" : "");
                  if(ObjectCreate(0, arrow_name, m_direction == LONG ? OBJ_ARROW_UP : OBJ_ARROW_DOWN, 0, TimeCurrent(), iClose(_Symbol, _Period, 1)))
                  {
                     ObjectSetInteger(0, arrow_name, OBJPROP_COLOR, clrRed);
                     CheckObjectExists(arrow_name);
                  }
                  string label_name = "Debug_Label_ChildFail_" + TimeToString(TimeCurrent()) + (m_is_test ? "_Test" : "");
                  if(ObjectCreate(0, label_name, OBJ_TEXT, 0, TimeCurrent(), iClose(_Symbol, _Period, 1)))
                  {
                     ObjectSetString(0, label_name, OBJPROP_TEXT, "فرزند " + (StringFind(m_name, "Child1") >= 0 ? "اول" : "دوم") + " شکست خورد (تأییدشده)");
                     ObjectSetInteger(0, label_name, OBJPROP_COLOR, clrRed);
                  }
               }
               return true;
            }
         }
      }
      return false;
   }

   bool CheckSuccessChild2(double current_price)
   {
      if(m_parent_mother == NULL || !m_is_success_child2) return false;
      string temp_levels[];
      int count = StringSplit(InpGoldenZone, StringGetCharacter(",", 0), temp_levels);
      if(count < 2) return false;
      double level_1 = StringToDouble(temp_levels[0]) / 100.0;
      double level_2 = StringToDouble(temp_levels[1]) / 100.0;
      double price_level_1 = m_price100 + (m_price0 - m_price100) * level_1;
      double price_level_2 = m_price100 + (m_price0 - m_price100) * level_2;
      double zone_lower = MathMin(price_level_1, price_level_2);
      double zone_upper = MathMax(price_level_1, price_level_2);
      bool success_condition = (current_price >= zone_lower && current_price <= zone_upper);
      if(success_condition)
      {
         Log("ساختار پیچیده وارد ناحیه طلایی شد: قیمت=" + DoubleToString(current_price, _Digits));
         if(InpVisualDebug)
         {
            string arrow_name = "Debug_Arrow_Signal_" + TimeToString(TimeCurrent()) + (m_is_test ? "_Test" : "");
            if(ObjectCreate(0, arrow_name, m_direction == LONG ? OBJ_ARROW_UP : OBJ_ARROW_DOWN, 0, TimeCurrent(), current_price))
            {
               ObjectSetInteger(0, arrow_name, OBJPROP_COLOR, clrGold);
               CheckObjectExists(arrow_name);
            }
         }
         return true;
      }
      return false;
   }

   bool CheckFailureChild2OnNewBar()
   {
      if(m_parent_mother == NULL) return false;
      double target_level = 250.0;
      bool level_found = false;
      for(int i = 0; i < m_parent_mother.GetLevelsCount(); i++)
      {
         if(MathAbs(m_parent_mother.GetLevel(i) - target_level) < 0.01)
         {
            level_found = true;
            double break_level;
            if(m_direction == LONG)
               break_level = m_parent_mother.GetPrice100() + (m_parent_mother.GetPrice100() - m_parent_mother.GetPrice0()) * (target_level / 100.0);
            else
               break_level = m_parent_mother.GetPrice100() - (m_parent_mother.GetPrice0() - m_parent_mother.GetPrice100()) * (target_level / 100.0);
            bool break_condition = false;
            if(InpStructureBreakMode == STRUCTURE_PRICE_CROSS)
               break_condition = (m_direction == LONG && iHigh(_Symbol, _Period, 1) >= break_level) ||
                                 (m_direction == SHORT && iLow(_Symbol, _Period, 1) <= break_level);
            else if(InpStructureBreakMode == STRUCTURE_CANDLE_CLOSE)
               break_condition = (m_direction == LONG && iClose(_Symbol, _Period, 1) >= break_level && iOpen(_Symbol, _Period, 0) >= break_level) ||
                                 (m_direction == SHORT && iClose(_Symbol, _Period, 1) <= break_level && iOpen(_Symbol, _Period, 0) <= break_level);
            if(break_condition)
            {
               Log("ساختار شکست خورد: عبور از سطح 250% مادر: قیمت=" + DoubleToString(iClose(_Symbol, _Period, 1), _Digits));
               if(InpVisualDebug)
               {
                  string label_name = "Debug_Label_StructureFail_" + TimeToString(TimeCurrent()) + (m_is_test ? "_Test" : "");
                  if(ObjectCreate(0, label_name, OBJ_TEXT, 0, TimeCurrent(), iClose(_Symbol, _Period, 1)))
                  {
                     ObjectSetString(0, label_name, OBJPROP_TEXT, "ساختار شکست خورد: عبور از سطح 250% مادر");
                     ObjectSetInteger(0, label_name, OBJPROP_COLOR, clrRed);
                     CheckObjectExists(label_name);
                  }
                  string arrow_name = "Debug_Arrow_StructureFail_" + TimeToString(TimeCurrent()) + (m_is_test ? "_Test" : "");
                  if(ObjectCreate(0, arrow_name, m_direction == LONG ? OBJ_ARROW_UP : OBJ_ARROW_DOWN, 0, TimeCurrent(), iClose(_Symbol, _Period, 1)))
                  {
                     ObjectSetInteger(0, arrow_name, OBJPROP_COLOR, clrRed);
                     CheckObjectExists(arrow_name);
                  }
               }
               return true;
            }
            break;
         }
      }
      if(!level_found) Log("هشدار: سطح 250% در InpMotherLevels یافت نشد.");
      return false;
   }

   bool CheckFailureChild2OnTick(double current_price)
   {
      if(m_parent_mother == NULL) return false;
      double level_0 = m_price0;
      bool fail_condition = (m_direction == LONG && current_price <= level_0) ||
                            (m_direction == SHORT && current_price >= level_0);
      if(fail_condition)
      {
         Log("ساختار شکست خورد: لنگرگاه مادر سوراخ شد: قیمت=" + DoubleToString(current_price, _Digits));
         if(InpVisualDebug)
         {
            string label_name = "Debug_Label_StructureFail_" + TimeToString(TimeCurrent()) + (m_is_test ? "_Test" : "");
            if(ObjectCreate(0, label_name, OBJ_TEXT, 0, TimeCurrent(), current_price))
            {
               ObjectSetString(0, label_name, OBJPROP_TEXT, "ساختار شکست خورد: لنگرگاه مادر سوراخ شد");
               ObjectSetInteger(0, label_name, OBJPROP_COLOR, clrRed);
            }
         }
         return true;
      }
      return false;
   }

   SFibonacciEventData GetEventData()
   {
      SFibonacciEventData data;
      data.child1_fix_time = m_fixation_time;
      data.child1_fix_price = m_fixation_price;
      data.child1_breakout_time = m_breakout_time;
      data.child1_breakout_price = m_breakout_price;
      string result = "";
      for(int i = 0; i < ArraySize(m_levels); i++)
      {
         double level_price = m_price100 + (m_price0 - m_price100) * (m_levels[i] / 100.0);
         result += "L" + (string)m_levels[i] + ":" + DoubleToString(level_price, _Digits) + ";";
      }
      data.child2_levels_string = result;
      return data;
   }

   void Delete()
   {
      CBaseFibo::Delete();
      ObjectDelete(0, m_golden_zone_name + (m_is_test ? "_Test" : ""));
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
   bool m_is_test;
   bool m_is_child1_fixed; // پرچم برای فیکس شدن فرزند اول

   void Log(string message)
   {
      if(InpEnableLog)
         CStructureManager::AddLog(m_id + ": " + message);
   }

   // متد جدید برای شبیه‌سازی تاریخچه تا زمان حال
   void SimulateToPresent()
   {
      if(m_mother == NULL) return;

      // آماده‌سازی: پیدا کردن اندیس کندل‌های شروع و پایان
      int mother_zero_index = iBarShift(_Symbol, _Period, m_mother.GetTime0());
      int current_index = iBarShift(_Symbol, _Period, TimeCurrent());
      if(mother_zero_index < 0 || current_index < 0) return;

      ENUM_STRUCTURE_STATE sim_state = MOTHER_ACTIVE;
      CChildFibo* sim_child1 = NULL;
      CChildFibo* sim_child2 = NULL;
      bool is_child1_fixed = false;
      datetime child1_fix_time = 0;
      double child1_fix_price = 0.0;

      // حلقه شبیه‌سازی از کندل بعد از نقطه صفر مادر تا کندل فعلی
      for(int i = mother_zero_index - 1; i >= current_index && sim_state != FAILED && sim_state != COMPLETED; i--)
      {
         datetime candle_time = iTime(_Symbol, _Period, i);
         double high = iHigh(_Symbol, _Period, i);
         double low = iLow(_Symbol, _Period, i);
         double close = iClose(_Symbol, _Period, i);

         if(sim_state == MOTHER_ACTIVE)
         {
            // بررسی فیکس شدن مادر
            double level_50 = m_mother.GetPrice100() + (m_mother.GetPrice0() - m_mother.GetPrice100()) * 0.5;
            bool fix_condition = (m_direction == LONG && close >= level_50 && InpMotherFixMode == FIX_CANDLE_CLOSE) ||
                                 (m_direction == SHORT && close <= level_50 && InpMotherFixMode == FIX_CANDLE_CLOSE) ||
                                 (m_direction == LONG && high >= level_50 && InpMotherFixMode == FIX_PRICE_CROSS) ||
                                 (m_direction == SHORT && low <= level_50 && InpMotherFixMode == FIX_PRICE_CROSS);

            if(fix_condition)
            {
               // ایجاد فرزند اول موقت
               sim_child1 = new CChildFibo(m_id + "_Child1", InpChild1Color, InpChildLevels, m_mother, false, m_is_test);
               if(sim_child1 == NULL || !sim_child1.Initialize(candle_time))
               {
                  Log("خطا در ایجاد فرزند اول در شبیه‌سازی");
                  delete sim_child1;
                  sim_state = FAILED;
                  break;
               }
               sim_state = CHILD1_ACTIVE;
               Log("شبیه‌سازی: مادر فیکس شد، فرزند اول فعال شد در " + TimeToString(candle_time));
            }
         }
         else if(sim_state == CHILD1_ACTIVE && sim_child1 != NULL)
         {
            // آپدیت سقف/کف فرزند اول اگر فیکس نشده باشد
            if(!is_child1_fixed)
            {
               sim_child1.UpdateOnTick(candle_time);
            }

            // بررسی فیکس شدن فرزند اول
            if(!is_child1_fixed)
            {
               double current_price = (InpMotherFixMode == FIX_CANDLE_CLOSE) ? close : (m_direction == LONG ? low : high);
               if(sim_child1.CheckFixing(current_price))
               {
                  is_child1_fixed = true;
                  child1_fix_time = candle_time;
                  child1_fix_price = current_price;
                  Log("شبیه‌سازی: فرزند اول فیکس شد در " + TimeToString(candle_time));
               }
            }

            // بررسی شکست سطح 100% مادر برای تولد فرزند دوم ساده
            double mother_level_100 = m_mother.GetPrice100();
            bool simple_break_condition = false;
            if(InpChildBreakMode == CHILD_PRICE_CROSS)
            {
               simple_break_condition = (m_direction == LONG && high > mother_level_100) ||
                                       (m_direction == SHORT && low < mother_level_100);
            }
            else if(InpChildBreakMode == CHILD_CONFIRMED_BREAK)
            {
               simple_break_condition = (m_direction == LONG && close >= mother_level_100) ||
                                       (m_direction == SHORT && close <= mother_level_100);
            }

            if(simple_break_condition)
            {
               // بررسی سطح 150 تا 200 مادر برای فرزند دوم ساده
               double mother_level_150 = m_mother.GetPrice100() + (m_mother.GetPrice0() - m_mother.GetPrice100()) * 1.5;
               double mother_level_200 = m_mother.GetPrice100() + (m_mother.GetPrice0() - m_mother.GetPrice100()) * 2.0;
               bool simple_child2_condition = (m_direction == LONG && high >= mother_level_150 && high <= mother_level_200) ||
                                             (m_direction == SHORT && low <= mother_level_150 && low >= mother_level_200);

               if(simple_child2_condition)
               {
                  if(sim_child1 != NULL) { sim_child1.Delete(); delete sim_child1; sim_child1 = NULL; }
                  sim_child2 = new CChildFibo(m_id + "_FailureChild2", InpChild2Color, InpChildLevels, m_mother, false, m_is_test);
                  if(sim_child2 == NULL || !sim_child2.Initialize(candle_time))
                  {
                     Log("خطا در ایجاد فرزند دوم ساده در شبیه‌سازی");
                     delete sim_child2;
                     sim_state = FAILED;
                     break;
                  }
                  sim_state = CHILD2_ACTIVE;
                  Log("شبیه‌سازی: فرزند دوم ساده فعال شد در " + TimeToString(candle_time));
               }
            }

            // بررسی شکست سطح 100% فرزند اول برای تولد فرزند دوم پیچیده
            if(is_child1_fixed)
            {
               bool complex_break_condition = (m_direction == LONG && high > sim_child1.GetPrice100()) ||
                                             (m_direction == SHORT && low < sim_child1.GetPrice100());
               if(complex_break_condition)
               {
                  // پیدا کردن نقطه صفر فرزند دوم پیچیده
                  int fix_index = iBarShift(_Symbol, _Period, child1_fix_time);
                  int break_index = i;
                  double new_zero_price = (m_direction == LONG) ? low : high;
                  datetime new_zero_time = candle_time;

                  for(int j = fix_index; j >= break_index; j--)
                  {
                     double candle_low = iLow(_Symbol, _Period, j);
                     double candle_high = iHigh(_Symbol, _Period, j);
                     if(m_direction == LONG && candle_low < new_zero_price)
                     {
                        new_zero_price = candle_low;
                        new_zero_time = iTime(_Symbol, _Period, j);
                     }
                     else if(m_direction == SHORT && candle_high > new_zero_price)
                     {
                        new_zero_price = candle_high;
                        new_zero_time = iTime(_Symbol, _Period, j);
                     }
                  }

                  if(sim_child1 != NULL) { sim_child1.Delete(); delete sim_child1; sim_child1 = NULL; }
                  sim_child2 = new CChildFibo(m_id + "_SuccessChild2", InpChild2Color, InpChildLevels, m_mother, true, m_is_test);
                  if(sim_child2 == NULL)
                  {
                     Log("خطا در ایجاد فرزند دوم پیچیده در شبیه‌سازی");
                     sim_state = FAILED;
                     break;
                  }
                  sim_child2.SetPoints(new_zero_time, new_zero_price, candle_time, (m_direction == LONG) ? high : low);
                  if(!sim_child2.Draw())
                  {
                     Log("خطا در رسم فرزند دوم پیچیده در شبیه‌سازی");
                     delete sim_child2;
                     sim_state = FAILED;
                     break;
                  }
                  sim_state = CHILD2_ACTIVE;
                  Log("شبیه‌سازی: فرزند دوم پیچیده فعال شد در " + TimeToString(candle_time));
               }
            }
         }
         else if(sim_state == CHILD2_ACTIVE && sim_child2 != NULL)
         {
            // بررسی ورود به ناحیه طلایی برای تکمیل ساختار
            double current_price = (InpStructureBreakMode == STRUCTURE_CANDLE_CLOSE) ? close : (m_direction == LONG ? low : high);
            if(sim_child2.CheckSuccessChild2(current_price))
            {
               sim_state = COMPLETED;
               Log("شبیه‌سازی: ساختار با ورود به ناحیه طلایی کامل شد");
            }
            // بررسی شکست ساختار
            else if(sim_child2.CheckFailureChild2OnTick(current_price))
            {
               sim_state = FAILED;
               Log("شبیه‌سازی: ساختار شکست خورد: لنگرگاه مادر سوراخ شد");
            }
            else if(i == current_index && sim_child2.CheckFailureChild2OnNewBar())
            {
               sim_state = FAILED;
               Log("شبیه‌سازی: ساختار شکست خورد: عبور از سطح 250% مادر");
            }
         }

         // بررسی شکست کلی ساختار
         if(sim_state != FAILED)
         {
            double mother_zero = m_mother.GetPrice0();
            bool structure_fail = (m_direction == LONG && low <= mother_zero) ||
                                 (m_direction == SHORT && high >= mother_zero);
            if(structure_fail)
            {
               sim_state = FAILED;
               Log("شبیه‌سازی: ساختار شکست خورد: لنگرگاه مادر سوراخ شد");
            }
         }
      }

      // ثبت نتایج نهایی شبیه‌سازی
      m_state = sim_state;
      m_child1 = sim_child1;
      m_child2 = sim_child2;
      m_is_child1_fixed = is_child1_fixed;
      Log("شبیه‌سازی تا زمان حال کامل شد، وضعیت نهایی: " + EnumToString(m_state));
   }

public:
   CFamily(string id, ENUM_DIRECTION direction, bool is_test)
   {
      m_id = id;
      m_state = SEARCHING;
      m_direction = direction;
      m_mother = NULL;
      m_child1 = NULL;
      m_child2 = NULL;
      m_is_test = is_test;
      m_is_child1_fixed = false;
   }

   bool Initialize(SBrokenFractal &fractal)
   {
      m_mother = new CMotherFibo(m_id + "_Mother", InpMotherColor, InpMotherLevels, m_direction, m_is_test);
      if(m_mother == NULL) return false;

      double price0 = 0;
      datetime time0 = 0;
      int bar_index_0 = -1;

      if(m_direction == LONG)
      {
         price0 = iLow(_Symbol, _Period, iBarShift(_Symbol, _Period, fractal.time));
         bar_index_0 = iBarShift(_Symbol, _Period, fractal.time);

         for(int i = iBarShift(_Symbol, _Period, fractal.time); i >= iBarShift(_Symbol, _Period, fractal.break_time); i--)
         {
            double current_low = iLow(_Symbol, _Period, i);
            if(current_low < price0)
            {
               price0 = current_low;
               bar_index_0 = i;
            }
         }
      }
      else // SHORT
      {
         price0 = iHigh(_Symbol, _Period, iBarShift(_Symbol, _Period, fractal.time));
         bar_index_0 = iBarShift(_Symbol, _Period, fractal.time);

         for(int i = iBarShift(_Symbol, _Period, fractal.time); i >= iBarShift(_Symbol, _Period, fractal.break_time); i--)
         {
            double current_high = iHigh(_Symbol, _Period, i);
            if(current_high > price0)
            {
               price0 = current_high;
               bar_index_0 = i;
            }
         }
      }

      if(bar_index_0 != -1)
         time0 = iTime(_Symbol, _Period, bar_index_0);

      if(m_mother.Initialize(time0, price0, fractal.time, fractal.price))
      {
         m_state = MOTHER_ACTIVE;
         Log("ساختار در حالت مادر فعال");
         SimulateToPresent(); // فراخوانی شبیه‌سازی بلافاصله پس از ایجاد مادر
         return true;
      }
      delete m_mother;
      m_mother = NULL;
      return false;
   }

   bool UpdateOnTick(double current_price, datetime current_time)
   {
      if(m_state == SEARCHING || m_state == FAILED || m_state == COMPLETED) return true;

      // بررسی شکست کلی ساختار
      if(m_mother != NULL)
      {
         if((m_direction == LONG && current_price <= m_mother.GetPrice0()) ||
            (m_direction == SHORT && current_price >= m_mother.GetPrice0()))
         {
            m_state = FAILED;
            Log("ساختار شکست خورد: لنگرگاه مادر سوراخ شد");
            return false;
         }
      }

      // بررسی ورود به ناحیه طلایی برای فرزند دوم پیچیده
      if(m_state == CHILD2_ACTIVE && m_child2 != NULL && m_child2.IsSuccessChild2())
      {
         if(m_child2.CheckSuccessChild2(current_price))
         {
            m_state = COMPLETED;
            Log("ساختار با ورود به ناحیه طلایی کامل شد");
         }
      }

      return true;
   }

   bool UpdateOnNewBar()
   {
      if(m_state == SEARCHING || m_state == FAILED || m_state == COMPLETED) return true;

      // بررسی شکست ساختار در فرزند دوم
      if(m_state == CHILD2_ACTIVE && m_child2 != NULL)
      {
         if(m_child2.CheckFailureChild2OnNewBar())
         {
            m_state = FAILED;
            Log("ساختار شکست خورد: عبور از سطح 250% مادر");
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
      if(count < 2)
      {
         Log("خطا: InpGoldenZone باید حداقل دو سطح داشته باشد");
         return signal;
      }
      double level_1 = StringToDouble(temp_levels[0]) / 100.0;
      double level_2 = StringToDouble(temp_levels[1]) / 100.0;
      double price_level_1 = m_child2.GetPrice100() + (m_child2.GetPrice0() - m_child2.GetPrice100()) * level_1;
      double price_level_2 = m_child2.GetPrice100() + (m_child2.GetPrice0() - m_child2.GetPrice100()) * level_2; // اصلاح نام متغیر
      double zone_lower = MathMin(price_level_1, price_level_2);
      double zone_upper = MathMax(price_level_1, price_level_2);
      double current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(current_price >= zone_lower && current_price <= zone_upper)
      {
         signal.type = m_direction == LONG ? "Buy" : "Sell";
         signal.id = m_id + "_" + TimeToString(TimeCurrent()) + "_" + (m_direction == LONG ? "Long" : "Short") + "_" + (m_child2.IsSuccessChild2() ? "Complex" : "Simple");
         Log("سیگنال " + signal.type + " صادر شد: ID=" + signal.id);
         m_state = COMPLETED;
      }
   }
   return signal;
}
   SFibonacciEventData GetLastEventData()
   {
      if(m_child2 != NULL) return m_child2.GetEventData();
      if(m_child1 != NULL) return m_child1.GetEventData();
      SFibonacciEventData empty_data;
      return empty_data;
   }

   void Destroy()
   {
      if(m_child2 != NULL) { m_child2.Delete(); delete m_child2; m_child2 = NULL; }
      if(m_child1 != NULL) { m_child1.Delete(); delete m_child1; m_child1 = NULL; }
      if(m_mother != NULL) { m_mother.Delete(); delete m_mother; m_mother = NULL; }
      m_state = FAILED;
      if(InpVisualDebug) ClearDebugObjects(m_is_test);
   }

   double GetMotherPrice0()
   {
      if(m_mother != NULL) return m_mother.GetPrice0();
      return 0.0;
   }

   ENUM_STRUCTURE_STATE GetState() { return m_state; }
   bool IsActive() { return m_state != COMPLETED && m_state != FAILED; }
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
   string m_log_buffer;
   CFractalFinder m_fractal_finder;
   SFractal m_unbrokenHighs[150];
   SFractal m_unbrokenLows[150];
   int m_unbrokenHighs_total;
   int m_unbrokenLows_total;
   datetime m_lastFractalScanTime;
   SBrokenFractal m_lastBrokenHigh;
   SBrokenFractal m_lastBrokenLow;
   SPendingBreakout m_pendingHighBreak;
   SPendingBreakout m_pendingLowBreak;
   ENUM_DIRECTION m_pendingDirection;

   void Log(string message)
   {
      if(InpEnableLog)
      {
         string log_entry = TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES | TIME_SECONDS) + ": " + message + "\n";
         m_log_buffer += log_entry;
         Print(log_entry);
      }
   }

   void FlushLog()
   {
      if(InpEnableLog && m_log_buffer != "")
      {
         int handle = FileOpen(InpLogFilePath, FILE_WRITE | FILE_TXT | FILE_COMMON);
         if(handle != INVALID_HANDLE)
         {
            FileSeek(handle, 0, SEEK_END);
            FileWrite(handle, m_log_buffer);
            FileClose(handle);
            m_log_buffer = "";
         }
         else
         {
            Print("خطا در باز کردن فایل لاگ: " + InpLogFilePath);
         }
      }
   }

   void DrawUnbrokenFractals()
   {
      if(!InpVisualDebug) return;
      for(int i = ObjectsTotal(0, -1, OBJ_ARROW) - 1; i >= 0; i--)
      {
         string obj_name = ObjectName(0, i);
         if(StringFind(obj_name, "Debug_Arrow_Fractal_") >= 0)
            ObjectDelete(0, obj_name);
      }
      for(int i = 0; i < m_unbrokenHighs_total; i++)
      {
         string arrow_name = "Debug_Arrow_Fractal_High_" + TimeToString(m_unbrokenHighs[i].time) + (m_is_test_mode ? "_Test" : "");
         if(ObjectCreate(0, arrow_name, OBJ_ARROW_UP, 0, m_unbrokenHighs[i].time, m_unbrokenHighs[i].price))
         {
            ObjectSetInteger(0, arrow_name, OBJPROP_COLOR, clrSkyBlue);
            ObjectSetInteger(0, arrow_name, OBJPROP_WIDTH, 1);
            CheckObjectExists(arrow_name);
         }
      }
      for(int i = 0; i < m_unbrokenLows_total; i++)
      {
         string arrow_name = "Debug_Arrow_Fractal_Low_" + TimeToString(m_unbrokenLows[i].time) + (m_is_test_mode ? "_Test" : "");
         if(ObjectCreate(0, arrow_name, OBJ_ARROW_DOWN, 0, m_unbrokenLows[i].time, m_unbrokenLows[i].price))
         {
            ObjectSetInteger(0, arrow_name, OBJPROP_COLOR, clrOrangeRed);
            ObjectSetInteger(0, arrow_name, OBJPROP_WIDTH, 1);
            CheckObjectExists(arrow_name);
         }
      }
   }

   void FindAndStoreFractals(bool is_initial_scan)
   {
      if(iBars(_Symbol, InpFractalTimeframe) < InpFractalPeers + 1)
      {
         Log("خطا: داده‌های چارت کافی نیست برای تایم‌فریم " + EnumToString(InpFractalTimeframe));
         return;
      }

      datetime lookback_time = iTime(_Symbol, InpFractalTimeframe, InpFractalLookback);

      for(int i = m_unbrokenHighs_total - 1; i >= 0; i--)
      {
         if(m_unbrokenHighs[i].time < lookback_time)
         {
            for(int j = i; j < m_unbrokenHighs_total - 1; j++)
               m_unbrokenHighs[j] = m_unbrokenHighs[j+1];
            m_unbrokenHighs_total--;
         }
      }
      for(int i = m_unbrokenLows_total - 1; i >= 0; i--)
      {
         if(m_unbrokenLows[i].time < lookback_time)
         {
            for(int j = i; j < m_unbrokenLows_total - 1; j++)
               m_unbrokenLows[j] = m_unbrokenLows[j+1];
            m_unbrokenLows_total--;
         }
      }

      datetime start_time = is_initial_scan ? iTime(_Symbol, InpFractalTimeframe, InpFractalLookback) : m_lastFractalScanTime;
      int start_index = iBarShift(_Symbol, InpFractalTimeframe, start_time);
      int end_index = is_initial_scan ? InpFractalPeers : 1;
      for(int i = start_index; i >= end_index; i--)
      {
         if(m_fractal_finder.IsHighFractal(i, InpFractalTimeframe, InpFractalPeers))
         {
            SFractal fractal;
            fractal.price = iHigh(_Symbol, InpFractalTimeframe, i);
            fractal.time = iTime(_Symbol, InpFractalTimeframe, i);
            if(m_unbrokenHighs_total < 150)
            {
               for(int j = m_unbrokenHighs_total; j > 0; j--)
                  m_unbrokenHighs[j] = m_unbrokenHighs[j-1];
               m_unbrokenHighs[0] = fractal;
               m_unbrokenHighs_total++;
            }
            else
            {
               double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
               int farthest_index = 0;
               double max_distance = MathAbs(m_unbrokenHighs[0].price - bid);
               for(int j = 1; j < m_unbrokenHighs_total; j++)
               {
                  double distance = MathAbs(m_unbrokenHighs[j].price - bid);
                  if(distance > max_distance)
                  {
                     max_distance = distance;
                     farthest_index = j;
                  }
               }
               Log("هشدار: آرایه فرکتال‌های سقف پر است، فرکتال دورتر از قیمت فعلی حذف شد: شاخص=" + (string)farthest_index);
               for(int j = farthest_index; j < m_unbrokenHighs_total - 1; j++)
                  m_unbrokenHighs[j] = m_unbrokenHighs[j+1];
               m_unbrokenHighs_total--;
               m_unbrokenHighs[m_unbrokenHighs_total] = fractal;
               m_unbrokenHighs_total++;
            }
         }
         if(m_fractal_finder.IsLowFractal(i, InpFractalTimeframe, InpFractalPeers))
         {
            SFractal fractal;
            fractal.price = iLow(_Symbol, InpFractalTimeframe, i);
            fractal.time = iTime(_Symbol, InpFractalTimeframe, i);
            if(m_unbrokenLows_total < 150)
            {
               for(int j = m_unbrokenLows_total; j > 0; j--)
                  m_unbrokenLows[j] = m_unbrokenLows[j-1];
               m_unbrokenLows[0] = fractal;
               m_unbrokenLows_total++;
            }
            else
            {
               double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
               int farthest_index = 0;
               double max_distance = MathAbs(m_unbrokenLows[0].price - bid);
               for(int j = 1; j < m_unbrokenLows_total; j++)
               {
                  double distance = MathAbs(m_unbrokenLows[j].price - bid);
                  if(distance > max_distance)
                  {
                     max_distance = distance;
                     farthest_index = j;
                  }
               }
               Log("هشدار: آرایه فرکتال‌های کف پر است، فرکتال دورتر از قیمت فعلی حذف شد: شاخص=" + (string)farthest_index);
               for(int j = farthest_index; j < m_unbrokenLows_total - 1; j++)
                  m_unbrokenLows[j] = m_unbrokenLows[j+1];
               m_unbrokenLows_total--;
               m_unbrokenLows[m_unbrokenLows_total] = fractal;
               m_unbrokenLows_total++;
            }
         }
      }
      m_lastFractalScanTime = iTime(_Symbol, InpFractalTimeframe, 0);
      DrawUnbrokenFractals();
   }

   //vvvvvvvvvv کل تابع CheckForBreakouts فعلی را با این کد کامل جایگزین کن vvvvvvvvvv
   void CheckForBreakouts()
   {
      // اگر در حالت انتظار برای شکست جدید نیستیم، این تابع نیازی به ساخت ساختار ندارد
      bool can_create_family = (InpStructureStartMode == WAIT_FOR_NEW_BREAK);

      // بخش اول: شناسایی شکست ها
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      datetime current_time = TimeCurrent();

      if(InpFractalBreakMode == SIMPLE_PRICE_CROSS)
      {
         for(int i = m_unbrokenHighs_total - 1; i >= 0; i--)
         {
            if(bid > m_unbrokenHighs[i].price)
            {
               SBrokenFractal broken;
               broken.time = m_unbrokenHighs[i].time;
               broken.price = m_unbrokenHighs[i].price;
               broken.direction = LONG;
               broken.break_time = current_time;
               broken.is_bos = m_pendingDirection == LONG;
               m_lastBrokenHigh = broken;
               for(int j = i; j < m_unbrokenHighs_total - 1; j++)
                  m_unbrokenHighs[j] = m_unbrokenHighs[j+1];
               m_unbrokenHighs_total--;
               Log("شکست سقف: قیمت=" + DoubleToString(broken.price, _Digits) + ", BOS=" + (broken.is_bos ? "true" : "false"));
               if(InpVisualDebug)
               {
                  string label_name = "Debug_Label_" + (broken.is_bos ? "BOS" : "CHOCH") + "_" + TimeToString(current_time) + (m_is_test_mode ? "_Test" : "");
                  if(ObjectCreate(0, label_name, OBJ_TEXT, 0, current_time, broken.price))
                  {
                     ObjectSetString(0, label_name, OBJPROP_TEXT, broken.is_bos ? "BOS" : "CHOCH");
                     ObjectSetInteger(0, label_name, OBJPROP_COLOR, clrYellow);
                     ObjectSetInteger(0, label_name, OBJPROP_FONTSIZE, 8);
                  }
               }
            }
         }
         for(int i = m_unbrokenLows_total - 1; i >= 0; i--)
         {
            if(ask < m_unbrokenLows[i].price)
            {
               SBrokenFractal broken;
               broken.time = m_unbrokenLows[i].time;
               broken.price = m_unbrokenLows[i].price;
               broken.direction = SHORT;
               broken.break_time = current_time;
               broken.is_bos = m_pendingDirection == SHORT;
               m_lastBrokenLow = broken;
               for(int j = i; j < m_unbrokenLows_total - 1; j++)
                  m_unbrokenLows[j] = m_unbrokenLows[j+1];
               m_unbrokenLows_total--;
               Log("شکست کف: قیمت=" + DoubleToString(broken.price, _Digits) + ", BOS=" + (broken.is_bos ? "true" : "false"));
               if(InpVisualDebug)
               {
                  string label_name = "Debug_Label_" + (broken.is_bos ? "BOS" : "CHOCH") + "_" + TimeToString(current_time) + (m_is_test_mode ? "_Test" : "");
                  if(ObjectCreate(0, label_name, OBJ_TEXT, 0, current_time, broken.price))
                  {
                     ObjectSetString(0, label_name, OBJPROP_TEXT, broken.is_bos ? "BOS" : "CHOCH");
                     ObjectSetInteger(0, label_name, OBJPROP_COLOR, clrYellow);
                     ObjectSetInteger(0, label_name, OBJPROP_FONTSIZE, 8);
                  }
               }
            }
         }
      }
      else if(InpFractalBreakMode == FRACTAL_CANDLE_CLOSE)
      {
         for(int i = m_unbrokenHighs_total - 1; i >= 0; i--)
         {
            if(iClose(_Symbol, InpFractalTimeframe, 1) > m_unbrokenHighs[i].price)
            {
               SBrokenFractal broken;
               broken.time = m_unbrokenHighs[i].time;
               broken.price = m_unbrokenHighs[i].price;
               broken.direction = LONG;
               broken.break_time = iTime(_Symbol, InpFractalTimeframe, 1);
               broken.is_bos = m_pendingDirection == LONG;
               m_lastBrokenHigh = broken;
               for(int j = i; j < m_unbrokenHighs_total - 1; j++)
                  m_unbrokenHighs[j] = m_unbrokenHighs[j+1];
               m_unbrokenHighs_total--;
               Log("شکست سقف (کلوز): قیمت=" + DoubleToString(broken.price, _Digits) + ", BOS=" + (broken.is_bos ? "true" : "false"));
               if(InpVisualDebug)
               {
                  string label_name = "Debug_Label_" + (broken.is_bos ? "BOS" : "CHOCH") + "_" + TimeToString(broken.break_time) + (m_is_test_mode ? "_Test" : "");
                  if(ObjectCreate(0, label_name, OBJ_TEXT, 0, broken.break_time, broken.price))
                  {
                     ObjectSetString(0, label_name, OBJPROP_TEXT, broken.is_bos ? "BOS" : "CHOCH");
                     ObjectSetInteger(0, label_name, OBJPROP_COLOR, clrYellow);
                     ObjectSetInteger(0, label_name, OBJPROP_FONTSIZE, 8);
                  }
               }
            }
         }
         for(int i = m_unbrokenLows_total - 1; i >= 0; i--)
         {
            if(iClose(_Symbol, InpFractalTimeframe, 1) < m_unbrokenLows[i].price)
            {
               SBrokenFractal broken;
               broken.time = m_unbrokenLows[i].time;
               broken.price = m_unbrokenLows[i].price;
               broken.direction = SHORT;
               broken.break_time = iTime(_Symbol, InpFractalTimeframe, 1);
               broken.is_bos = m_pendingDirection == SHORT;
               m_lastBrokenLow = broken;
               for(int j = i; j < m_unbrokenLows_total - 1; j++)
                  m_unbrokenLows[j] = m_unbrokenLows[j+1];
               m_unbrokenLows_total--;
               Log("شکست کف (کلوز): قیمت=" + DoubleToString(broken.price, _Digits) + ", BOS=" + (broken.is_bos ? "true" : "false"));
               if(InpVisualDebug)
               {
                  string label_name = "Debug_Label_" + (broken.is_bos ? "BOS" : "CHOCH") + "_" + TimeToString(broken.break_time) + (m_is_test_mode ? "_Test" : "");
                  if(ObjectCreate(0, label_name, OBJ_TEXT, 0, broken.break_time, broken.price))
                  {
                     ObjectSetString(0, label_name, OBJPROP_TEXT, broken.is_bos ? "BOS" : "CHOCH");
                     ObjectSetInteger(0, label_name, OBJPROP_COLOR, clrYellow);
                     ObjectSetInteger(0, label_name, OBJPROP_FONTSIZE, 8);
                  }
               }
            }
         }
      }
      else if(InpFractalBreakMode == FRACTAL_CONFIRMED_BREAK)
      {
         if(m_pendingHighBreak.time != 0)
         {
            int shift = iBarShift(_Symbol, InpFractalTimeframe, m_pendingHighBreak.initial_break_time);
            if(shift <= 0 || m_pendingHighBreak.candles_left <= 0)
            {
               m_pendingHighBreak.time = 0;
               Log("شکست سقف تأیید نشد: تعداد کندل‌های فرصت به پایان رسید");
            }
            else
            {
               m_pendingHighBreak.candles_left--;
               if(iHigh(_Symbol, InpFractalTimeframe, 1) >= m_pendingHighBreak.initial_break_price)
               {
                  SBrokenFractal broken;
                  broken.time = m_pendingHighBreak.time;
                  broken.price = m_pendingHighBreak.price;
                  broken.direction = LONG;
                  broken.break_time = iTime(_Symbol, InpFractalTimeframe, 1);
                  broken.is_bos = m_pendingDirection == LONG;
                  m_lastBrokenHigh = broken;
                  for(int i = 0; i < m_unbrokenHighs_total; i++)
                  {
                     if(m_unbrokenHighs[i].time == broken.time)
                     {
                        for(int j = i; j < m_unbrokenHighs_total - 1; j++)
                           m_unbrokenHighs[j] = m_unbrokenHighs[j+1];
                        m_unbrokenHighs_total--;
                        break;
                     }
                  }
                  m_pendingHighBreak.time = 0;
                  Log("شکست سقف تأیید شد: قیمت=" + DoubleToString(broken.price, _Digits) + ", BOS=" + (broken.is_bos ? "true" : "false"));
                  if(InpVisualDebug)
                  {
                     string label_name = "Debug_Label_" + (broken.is_bos ? "BOS" : "CHOCH") + "_" + TimeToString(broken.break_time) + (m_is_test_mode ? "_Test" : "");
                     if(ObjectCreate(0, label_name, OBJ_TEXT, 0, broken.break_time, broken.price))
                     {
                        ObjectSetString(0, label_name, OBJPROP_TEXT, broken.is_bos ? "BOS" : "CHOCH");
                        ObjectSetInteger(0, label_name, OBJPROP_COLOR, clrYellow);
                        ObjectSetInteger(0, label_name, OBJPROP_FONTSIZE, 8);
                     }
                  }
               }
            }
         }
         else
         {
            for(int i = m_unbrokenHighs_total - 1; i >= 0; i--)
            {
               if(iClose(_Symbol, InpFractalTimeframe, 1) > m_unbrokenHighs[i].price)
               {
                  m_pendingHighBreak.time = m_unbrokenHighs[i].time;
                  m_pendingHighBreak.price = m_unbrokenHighs[i].price;
                  m_pendingHighBreak.direction = LONG;
                  m_pendingHighBreak.initial_break_time = iTime(_Symbol, InpFractalTimeframe, 1);
                  m_pendingHighBreak.initial_break_price = iHigh(_Symbol, InpFractalTimeframe, 1);
                  m_pendingHighBreak.candles_left = InpMaxBreakoutCandles;
                  Log("شکست اولیه سقف: قیمت=" + DoubleToString(m_pendingHighBreak.price, _Digits));
                  break;
               }
            }
         }

         if(m_pendingLowBreak.time != 0)
         {
            int shift = iBarShift(_Symbol, InpFractalTimeframe, m_pendingLowBreak.initial_break_time);
            if(shift <= 0 || m_pendingLowBreak.candles_left <= 0)
            {
               m_pendingLowBreak.time = 0;
               Log("شکست کف تأیید نشد: تعداد کندل‌های فرصت به پایان رسید");
            }
            else
            {
               m_pendingLowBreak.candles_left--;
               if(iLow(_Symbol, InpFractalTimeframe, 1) <= m_pendingLowBreak.initial_break_price)
               {
                  SBrokenFractal broken;
                  broken.time = m_pendingLowBreak.time;
                  broken.price = m_pendingLowBreak.price;
                  broken.direction = SHORT;
                  broken.break_time = iTime(_Symbol, InpFractalTimeframe, 1);
                  broken.is_bos = m_pendingDirection == SHORT;
                  m_lastBrokenLow = broken;
                  for(int i = 0; i < m_unbrokenLows_total; i++)
                  {
                     if(m_unbrokenLows[i].time == broken.time)
                     {
                        for(int j = i; j < m_unbrokenLows_total - 1; j++)
                           m_unbrokenLows[j] = m_unbrokenLows[j+1];
                        m_unbrokenLows_total--;
                        break;
                     }
                  }
                  m_pendingLowBreak.time = 0;
                  Log("شکست کف تأیید شد: قیمت=" + DoubleToString(broken.price, _Digits) + ", BOS=" + (broken.is_bos ? "true" : "false"));
                  if(InpVisualDebug)
                  {
                     string label_name = "Debug_Label_" + (broken.is_bos ? "BOS" : "CHOCH") + "_" + TimeToString(broken.break_time) + (m_is_test_mode ? "_Test" : "");
                     if(ObjectCreate(0, label_name, OBJ_TEXT, 0, broken.break_time, broken.price))
                     {
                        ObjectSetString(0, label_name, OBJPROP_TEXT, broken.is_bos ? "BOS" : "CHOCH");
                        ObjectSetInteger(0, label_name, OBJPROP_COLOR, clrYellow);
                        ObjectSetInteger(0, label_name, OBJPROP_FONTSIZE, 8);
                     }
                  }
               }
            }
         }
         else
         {
            for(int i = m_unbrokenLows_total - 1; i >= 0; i--)
            {
               if(iClose(_Symbol, InpFractalTimeframe, 1) < m_unbrokenLows[i].price)
               {
                  m_pendingLowBreak.time = m_unbrokenLows[i].time;
                  m_pendingLowBreak.price = m_unbrokenLows[i].price;
                  m_pendingLowBreak.direction = SHORT;
                  m_pendingLowBreak.initial_break_time = iTime(_Symbol, InpFractalTimeframe, 1);
                  m_pendingLowBreak.initial_break_price = iLow(_Symbol, InpFractalTimeframe, 1);
                  m_pendingLowBreak.candles_left = InpMaxBreakoutCandles;
                  Log("شکست اولیه کف: قیمت=" + DoubleToString(m_pendingLowBreak.price, _Digits));
                  break;
               }
            }
         }
      }
      
      // بخش دوم: ساخت ساختار در صورتی که در حالت انتظار باشیم
      if(can_create_family)
      {
         // آیا یک شکست سقف جدید داریم و نیت ما هم خرید بوده؟
         if(m_lastBrokenHigh.time != 0 && m_pendingDirection == LONG)
         {
            CFamily* new_family = new CFamily("Family_" + TimeToString(TimeCurrent()), LONG, m_is_test_mode);
            if(new_family != NULL && new_family.Initialize(m_lastBrokenHigh))
            {
               int size = ArraySize(m_families);
               ArrayResize(m_families, size + 1);
               m_families[size] = new_family;
               Log("ساختار خرید بر اساس شکست جدید " + TimeToString(m_lastBrokenHigh.time) + " ایجاد شد.");
               m_pendingDirection = DIRECTION_NONE;
               m_lastBrokenHigh.time = 0; // گزارش مصرف شد
               m_current_command = "Long Active";
            }
            else
            {
               delete new_family;
            }
         }
         // آیا یک شکست کف جدید داریم و نیت ما هم فروش بوده؟
         else if(m_lastBrokenLow.time != 0 && m_pendingDirection == SHORT)
         {
            CFamily* new_family = new CFamily("Family_" + TimeToString(TimeCurrent()), SHORT, m_is_test_mode);
            if(new_family != NULL && new_family.Initialize(m_lastBrokenLow))
            {
               int size = ArraySize(m_families);
               ArrayResize(m_families, size + 1);
               m_families[size] = new_family;
               Log("ساختار فروش بر اساس شکست جدید " + TimeToString(m_lastBrokenLow.time) + " ایجاد شد.");
               m_pendingDirection = DIRECTION_NONE;
               m_lastBrokenLow.time = 0; // گزارش مصرف شد
               m_current_command = "Short Active";
            }
            else
            {
               delete new_family;
            }
         }
      }
   }
//^^^^^^^^^^ پایان بلوک جایگزینی ^^^^^^^^^^


public:
   CStructureManager()
   {
      ArrayResize(m_families, 0);
      m_panel = NULL;
      m_test_panel = NULL;
      m_is_test_mode = InpTestMode;
      m_current_command = "";
      m_log_buffer = "";
      m_unbrokenHighs_total = 0;
      m_unbrokenLows_total = 0;
      m_lastFractalScanTime = 0;
      m_lastBrokenHigh.time = 0;
      m_lastBrokenLow.time = 0;
      m_pendingHighBreak.time = 0;
      m_pendingLowBreak.time = 0;
      m_pendingDirection = DIRECTION_NONE;
   }

   bool Initialize()
   {
      if(InpShowPanelEa)
      {
         m_panel = new CPanel("HipoFiboPanel", InpPanelCorner, InpPanelOffsetX, InpPanelOffsetY);
         if(m_panel == NULL || !m_panel.Create())
         {
            Log("خطا: ایجاد پنل اصلی ناموفق بود");
            return false;
         }
      }

      if(m_is_test_mode)
      {
         m_test_panel = new CTestPanel("HipoFiboTestPanel", InpTestPanelCorner, InpTestPanelOffsetX, InpTestPanelOffsetY,
                                       InpTestPanelButtonColorLong, InpTestPanelButtonColorShort, InpTestPanelButtonColorStop, InpTestPanelBgColor);
         if(m_test_panel == NULL || !m_test_panel.Create())
         {
            Log("خطا: ایجاد پنل تست ناموفق بود");
            return false;
         }
      }

      FindAndStoreFractals(true);
      Log("کتابخانه فیبوناچی با موفقیت راه‌اندازی شد");
      return true;
   }

   void Deinitialize()
   {
      for(int i = 0; i < ArraySize(m_families); i++)
      {
         if(m_families[i] != NULL)
         {
            m_families[i].Destroy();
            delete m_families[i];
         }
      }
      ArrayResize(m_families, 0);

      if(m_panel != NULL)
      {
         m_panel.Destroy();
         delete m_panel;
         m_panel = NULL;
      }

      if(m_test_panel != NULL)
      {
         m_test_panel.Destroy();
         delete m_test_panel;
         m_test_panel = NULL;
      }

      FlushLog();
      Log("کتابخانه فیبوناچی متوقف شد");
   }

   void OnTick()
   {
      CheckForBreakouts();
      double current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      datetime current_time = TimeCurrent();

      for(int i = 0; i < ArraySize(m_families); i++)
      {
         if(m_families[i] != NULL && m_families[i].IsActive())
         {
            if(!m_families[i].UpdateOnTick(current_price, current_time))
            {
               m_families[i].Destroy();
               delete m_families[i];
               m_families[i] = NULL;
            }
         }
      }

      if(m_panel != NULL)
      {
         string status = "تعداد ساختارها: " + (string)ArraySize(m_families);
         m_panel.UpdateStatus(status);
         m_panel.UpdateCommand(m_current_command);
      }

      if(m_is_test_mode && m_test_panel != NULL)
      {
         m_test_panel.UpdateSignal("", "");
      }

      FlushLog();
   }

   void OnNewBar()
   {
      FindAndStoreFractals(false);
      CheckForBreakouts();

      for(int i = 0; i < ArraySize(m_families); i++)
      {
         if(m_families[i] != NULL && m_families[i].IsActive())
         {
            if(!m_families[i].UpdateOnNewBar())
            {
               m_families[i].Destroy();
               delete m_families[i];
               m_families[i] = NULL;
            }
         }
      }
   }

   void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
   {
      if(!m_is_test_mode || m_test_panel == NULL) return;

      string command = "";
      if(m_test_panel.OnButtonClick(sparam, command))
      {
         if(command == "StartLong")
         {
            CreateNewStructure(LONG);
            Log("تست دستی: شروع ساختار خرید");
         }
         else if(command == "StartShort")
         {
            CreateNewStructure(SHORT);
            Log("تست دستی: شروع ساختار فروش");
         }
         else if(command == "Stop")
         {
            for(int i = 0; i < ArraySize(m_families); i++)
            {
               if(m_families[i] != NULL)
               {
                  m_families[i].Destroy();
                  delete m_families[i];
                  m_families[i] = NULL;
               }
            }
            ArrayResize(m_families, 0);
            Log("تست دستی: توقف تمام ساختارها");
         }
         m_current_command = command;
      }
   }

   //vvvvvvvvvv کل تابع CreateNewStructure فعلی را با این کد جایگزین کن vvvvvvvvvv
   bool CreateNewStructure(ENUM_DIRECTION direction)
   {
      if(ArraySize(m_families) >= InpMaxFamilies)
      {
         Log("خطا: یک ساختار از قبل فعال است.");
         return false;
      }
      
      // حالت اول: استفاده از آخرین شکست موجود
      if(InpStructureStartMode == USE_LAST_BREAK)
      {
         SBrokenFractal fractal_to_use = (direction == LONG) ? m_lastBrokenHigh : m_lastBrokenLow;
         
         if(fractal_to_use.time != 0)
         {
            CFamily* new_family = new CFamily("Family_" + TimeToString(TimeCurrent()), direction, m_is_test_mode);
            if(new_family != NULL && new_family.Initialize(fractal_to_use))
            {
               int size = ArraySize(m_families);
               ArrayResize(m_families, size + 1);
               m_families[size] = new_family;
               Log("ساختار " + (direction == LONG ? "خرید" : "فروش") + " بر اساس آخرین شکست موجود ایجاد شد.");
               m_current_command = (direction == LONG) ? "Long Active" : "Short Active";
               // گزارش شکست رو مصرف میکنیم
               if(direction == LONG) m_lastBrokenHigh.time = 0;
               else m_lastBrokenLow.time = 0;
               return true;
            }
            else
            {
               delete new_family;
               return false;
            }
         }
         else
         {
            Log("هیچ شکست اخیری برای استفاده یافت نشد. منتظر شکست جدید می‌مانیم...");
            // اگر شکست اخیری نبود، خودکار به حالت انتظار برای شکست جدید میرویم
            m_pendingDirection = direction;
            m_current_command = (direction == LONG) ? "Arm Long" : "Arm Short";
            return false; // ساختاری ایجاد نشد
         }
      }
      // حالت دوم: انتظار برای یک شکست کاملا جدید
      else // WAIT_FOR_NEW_BREAK
      {
         m_pendingDirection = direction;
         Log("کتابخانه برای شکار شکست جدید " + (direction == LONG ? "خرید" : "فروش") + " مسلح شد.");
         m_current_command = (direction == LONG) ? "Arm Long" : "Arm Short";
         return false; // هنوز ساختاری ایجاد نشده است
      }
   }
//^^^^^^^^^^ پایان بخش جایگزینی ^^^^^^^^^^

   void StopCurrentStructure()
   {
      for(int i = 0; i < ArraySize(m_families); i++)
      {
         if(m_families[i] != NULL)
         {
            m_families[i].Destroy();
            delete m_families[i];
            m_families[i] = NULL;
         }
      }
      ArrayResize(m_families, 0);
      Log("ساختار فعلی متوقف شد");
   }

   bool IsStructureBroken()
   {
      for(int i = 0; i < ArraySize(m_families); i++)
      {
         if(m_families[i] != NULL && m_families[i].GetState() == FAILED)
            return true;
      }
      return false;
   }

   SSignal GetSignal()
   {
      SSignal signal = {"", ""};
      for(int i = 0; i < ArraySize(m_families); i++)
      {
         if(m_families[i] != NULL && m_families[i].IsActive())
         {
            signal = m_families[i].GetSignal();
            if(signal.id != "") break;
         }
      }
      return signal;
   }

   void AcknowledgeSignal(string signal_id)
   {
      for(int i = 0; i < ArraySize(m_families); i++)
      {
         if(m_families[i] != NULL && m_families[i].GetSignal().id == signal_id)
         {
            m_families[i].Destroy();
            delete m_families[i];
            m_families[i] = NULL;
            Log("سیگنال تأیید شد و ساختار حذف شد: ID=" + signal_id);
         }
      }
   }

   double GetMotherZeroPoint()
   {
      for(int i = 0; i < ArraySize(m_families); i++)
      {
         if(m_families[i] != NULL && m_families[i].IsActive())
            return m_families[i].GetMotherPrice0();
      }
      return 0.0;
   }

   static void AddLog(string message)
   {
      if(InpEnableLog)
      {
         string log_entry = TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES | TIME_SECONDS) + ": " + message + "\n";
         Print(log_entry);
      }
   }
};

//+------------------------------------------------------------------+
//| متغیرهای سراسری و توابع اصلی                                  |
//+------------------------------------------------------------------+
CStructureManager* g_structure_manager = NULL;

bool HFiboOnInit()
{
   g_structure_manager = new CStructureManager();
   if(g_structure_manager == NULL || !g_structure_manager.Initialize())
   {
      delete g_structure_manager;
      g_structure_manager = NULL;
      return false;
   }
   return true;
}

void HFiboOnDeinit(const int reason)
{
   if(g_structure_manager != NULL)
   {
      g_structure_manager.Deinitialize();
      delete g_structure_manager;
      g_structure_manager = NULL;
   }
}

void HFiboOnTick()
{
   if(g_structure_manager != NULL)
      g_structure_manager.OnTick();
}

void HFiboOnNewBar()
{
   if(g_structure_manager != NULL)
      g_structure_manager.OnNewBar();
}

void HFiboOnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   if(g_structure_manager != NULL)
      g_structure_manager.OnChartEvent(id, lparam, dparam, sparam);
}

bool HFiboCreateNewStructure(ENUM_DIRECTION direction)
{
   if(g_structure_manager != NULL)
      return g_structure_manager.CreateNewStructure(direction);
   return false;
}

void HFiboStopCurrentStructure()
{
   if(g_structure_manager != NULL)
      g_structure_manager.StopCurrentStructure();
}

bool HFiboIsStructureBroken()
{
   if(g_structure_manager != NULL)
      return g_structure_manager.IsStructureBroken();
   return false;
}

SSignal HFiboGetSignal()
{
   if(g_structure_manager != NULL)
      return g_structure_manager.GetSignal();
   SSignal empty_signal = {"", ""};
   return empty_signal;
}

void HFiboAcknowledgeSignal(string signal_id)
{
   if(g_structure_manager != NULL)
      g_structure_manager.AcknowledgeSignal(signal_id);
}

double HFiboGetMotherZeroPoint()
{
   if(g_structure_manager != NULL)
      return g_structure_manager.GetMotherZeroPoint();
   return 0.0;
}

#endif
//+------------------------------------------------------------------+
