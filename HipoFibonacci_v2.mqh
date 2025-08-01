//+------------------------------------------------------------------+
//|                                                  HipoFibonacci.mqh |
//|                              محصولی از: Hipo Algorithm           |
//|                              نسخه: ۱.۶.۶                          |
//|                              تاریخ: ۲۰۲۵/۰۷/۲۵                   |
//| کتابخانه تحلیل فیبوناچی پویا برای متاتریدر ۵ با حالت تست    |
//+------------------------------------------------------------------+

#property copyright "Hipo Algorithm"
#property link      "https://hipoalgorithm.com"
#property version   "1.6.7"

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
input group "تنظیمات فراکتال"
input int InpFractalLookback = 200;       // حداکثر تعداد کندل برای جستجوی فراکتال (حداقل 10)
input int InpFractalPeers = 3;            // تعداد کندل‌های چپ/راست برای فراکتال (حداقل 1)

input group "سطوح فیبوناچی"
input string InpMotherLevels = "0,38,50,68,100,150,200,250"; // سطوح فیبو مادر (اعداد مثبت، با کاما)
input string InpChildLevels = "0,38,50,68,100,150,200,250";  // سطوح فیبو فرزندان (اعداد مثبت)
/*input*/ string InpChild2BreakLevels = "";              // سطوح شکست فرزند دوم (اختیاری، اعداد مثبت، با کاما)
input string InpGoldenZone = "38,50";                // ناحیه طلایی برای سیگنال (اعداد مثبت)

input group "فیکس شدن مادر"
enum ENUM_FIX_MODE
{
   PRICE_CROSS,   // عبور لحظه‌ای قیمت
   CANDLE_CLOSE   // کلوز کندل
};
input ENUM_FIX_MODE InpMotherFixMode = PRICE_CROSS; // حالت فیکس شدن مادر

input group "تخریب ساختار"
enum ENUM_STRUCTURE_BREAK_MODE
{
   PRICE_CROSS1,   // عبور لحظه‌ای قیمت
   CANDLE_CLOSE1   // کلوز کندل
};
input ENUM_STRUCTURE_BREAK_MODE InpStructureBreakMode = PRICE_CROSS1; // حالت تخریب ساختار

input group "شکست فرزند اول"
enum ENUM_CHILD_BREAK_MODE
{
   PRICE_CROSSS,     // عبور ساده قیمت
   CONFIRMED_BREAK   // شکست تأییدشده
};
input ENUM_CHILD_BREAK_MODE InpChildBreakMode = CONFIRMED_BREAK; // حالت شکست سطح 100% فرزند
input int InpMaxBreakoutCandles = 3;                            // حداکثر کندل‌های فرصت برای تأیید شکست

input group "رنگ‌بندی اشیاء"
input color InpMotherColor = clrWhite;    // رنگ فیبوناچی مادر
input color InpChild1Color = clrMagenta;     // رنگ فیبوناچی فرزند اول
input color InpChild2Color = clrGreen;    // رنگ فیبوناچی فرزند دوم

/*input*/// group "تنظیمات پنل اصلی"
/*input*/ bool InpShowPanelEa = true;           // نمایش پنل اصلی اطلاعاتی
 ENUM_BASE_CORNER InpPanelCorner = CORNER_LEFT_UPPER; // گوشه پنل اصلی
 int InpPanelOffsetX = 10;           // فاصله افقی پنل اصلی (حداقل 0)
 int InpPanelOffsetY = 136;           // فاصله عمودی پنل اصلی (حداقل 0)

//input group "تنظیمات حالت تست (هشدار: در این حالت اکسپرت نادیده گرفته می‌شود)"
/*input*/ bool InpTestMode = false;            // فعال‌سازی حالت تست داخلی
/*input*/ ENUM_BASE_CORNER InpTestPanelCorner = CORNER_RIGHT_UPPER; // گوشه پنل تست (مرکز بالا)
/*input*/ int InpTestPanelOffsetX = 153;      // فاصله افقی پنل تست از مرکز (حداقل 0)
/*input*/ int InpTestPanelOffsetY = 39;       // فاصله عمودی پنل تست از بالا (حداقل 0)
/*input*/ color InpTestPanelButtonColorLong = clrGreen;  // رنگ دکمه Start Long
/*input*/ color InpTestPanelButtonColorShort = clrRed;   // رنگ دکمه Stop
/*input*/ color InpTestPanelButtonColorStop = clrGray;   // رنگ دکمه Stop
/*input*/ color InpTestPanelBgColor = clrDarkGray;      // رنگ پس‌زمینه پنل تست

/*input*/ // group "تنظیمات دیباگ"
/*input*/  bool InpVisualDebug = false;        // فعال‌سازی حالت تست بصری

input group "تنظیمات لاگ"
input bool InpEnableLog = false;           // فعال‌سازی لاگ‌گیری
input string InpLogFilePath = "HipoFibonacci_Log.txt"; // مسیر فایل لاگ (MQL5/Files)
input int InpMaxFamilies = 1;             // حداکثر تعداد ساختارهای فعال (فقط 1)
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
// ... بعد از تعریف struct SFractal

// <<-- اضافه شد: ساختار جدید برای نگهداری داده‌های خروجی و رویدادهای کلیدی فیبوناچی -->>
struct SFibonacciEventData
{
   datetime child1_fix_time;          // زمان دقیق فیکس شدن فرزند اول
   double   child1_fix_price;         // قیمت در لحظه فیکس شدن فرزند اول
   datetime child1_breakout_time;     // زمان دقیق شکست سقف/کف فرزند اول
   double   child1_breakout_price;    // قیمت در لحظه شکست سقف/کف فرزند اول
   string   child2_levels_string;     // تمام سطوح فرزند دوم به صورت یک رشته
};

//+------------------------------------------------------------------+
//| کلاس CFractalFinder: پیدا کردن فراکتال‌ها                      |
//+------------------------------------------------------------------+
class CFractalFinder
{
private:
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

public:
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
      if(!ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0))
         return false;
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
      if(!ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0))
         return false;
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
      if(!ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0))
         return false;
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
      if(!ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0))
      {
         Print("خطا: نمی‌توان دکمه " + name + " را ایجاد کرد");
         return false;
      }
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
      if(!ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0))
      {
         Print("خطا: نمی‌توان پس‌زمینه " + name + " را ایجاد کرد");
         return false;
      }
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
      if(!ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0))
      {
         Print("خطا: نمی‌توان لیبل " + name + " را ایجاد کرد");
         return false;
      }
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
            if(InpEnableLog)
               Print("دکمه StartLong کلیک شد");
            return true;
         }
         if(StringFind(button, "_StartShort") >= 0)
         {
            command = "StartShort";
            ObjectSetInteger(0, button, OBJPROP_BGCOLOR, m_button_color_short);
            if(InpEnableLog)
               Print("دکمه StartShort کلیک شد");
            return true;
         }
         if(StringFind(button, "_Stop") >= 0)
         {
            command = "Stop";
            ObjectSetInteger(0, button, OBJPROP_BGCOLOR, m_button_color_stop);
            if(InpEnableLog)
               Print("دکمه Stop کلیک شد");
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
   bool m_is_visible; // وضعیت نمایش

public:
   CBaseFibo(string name, color clr, string levels, bool is_test)
   {
      m_name = name;
      m_color = clr;
      m_is_test = is_test;
      m_is_visible = false; // در ابتدا مخفی
      ArrayFree(m_levels);
      string temp_levels[];
      int count = StringSplit(levels, StringGetCharacter(",", 0), temp_levels);
      ArrayResize(m_levels, count);
      for(int i = 0; i < count; i++)
      {
         double level = StringToDouble(temp_levels[i]);
         if(level < 0)
         {
            Print("خطا: سطح فیبوناچی منفی غیرمجاز است: ", level);
            continue;
         }
         m_levels[i] = level;
      }
   }

   virtual bool Draw()
   {
      string obj_name = m_name + (m_is_test ? "_Test" : "");
      ObjectDelete(0, obj_name);
      if(!m_is_visible)
         return true;

      if(!ObjectCreate(0, obj_name, OBJ_FIBO, 0, m_time0, m_price0, m_time100, m_price100))
      {
         Print("خطا در ایجاد شیء فیبوناچی: ", obj_name);
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

   void SetVisibility(bool visible)
   {
      if(m_is_visible == visible) return;
      m_is_visible = visible;
      Draw();
   }

   bool IsVisible() { return m_is_visible; }

   datetime GetTime100() { return m_time100; }
   datetime GetTime0() { return m_time0; }
   double GetPrice0() { return m_price0; }
   double GetPrice100() { return m_price100; }
   double GetLevel(int index) { return index < ArraySize(m_levels) ? m_levels[index] : 0.0; }
   int GetLevelsCount() { return ArraySize(m_levels); }
};
//+------------------------------------------------------------------+
//| کلاس CMotherFibo: فیبوناچی مادر                                |
//+------------------------------------------------------------------+
class CMotherFibo : public CBaseFibo
{
private:
   bool m_is_fixed;
   ENUM_DIRECTION m_direction;
   double m_breakout_failure_price; // قیمت سطح شکست نهایی (مثل 200% یا بالاترین سطح)
   
   void Log(string message)
   {
      if(InpEnableLog)
         Print(TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES | TIME_SECONDS) + ": " + message);
   }


public:
  CMotherFibo(string name, color clr, string levels, ENUM_DIRECTION dir, bool is_test)
   : CBaseFibo(name, clr, levels, is_test)
{
   m_is_fixed = false;
   m_direction = dir;
   m_breakout_failure_price = 0.0;
}
   virtual bool Draw() override
   {
      string obj_name = m_name + (m_is_test ? "_Test" : "");
      ObjectDelete(0, obj_name);
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

   bool Initialize(SFractal &fractal, datetime current_time)
   {
      m_time100 = fractal.time;
      m_price100 = fractal.price;
      if(m_direction == LONG)
      {
         m_price0 = iLow(_Symbol, _Period, iBarShift(_Symbol, _Period, fractal.time));
         for(int i = iBarShift(_Symbol, _Period, fractal.time); i >= iBarShift(_Symbol, _Period, current_time); i--)
            m_price0 = MathMin(m_price0, iLow(_Symbol, _Period, i));
      }
      else
      {
         m_price0 = iHigh(_Symbol, _Period, iBarShift(_Symbol, _Period, fractal.time));
         for(int i = iBarShift(_Symbol, _Period, fractal.time); i >= iBarShift(_Symbol, _Period, current_time); i--)
            m_price0 = MathMax(m_price0, iHigh(_Symbol, _Period, i));
      }
      m_time0 = current_time;
      if(Draw())
      {
         Log("مادر متولد شد: صد=" + DoubleToString(m_price100, _Digits) + ", صفر=" + DoubleToString(m_price0, _Digits) + ", زمان=" + TimeToString(m_time0));
         if(InpVisualDebug)
         {
            string arrow_name = "Debug_Arrow_Fractal_" + TimeToString(m_time100) + (m_is_test ? "_Test" : "");
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

   bool UpdateOnTick(datetime new_time)
   {
      if(m_is_fixed) return true;
      double old_price0 = m_price0;
      if(m_direction == LONG)
      {
         m_price0 = MathMin(m_price0, iLow(_Symbol, _Period, iBarShift(_Symbol, _Period, new_time)));
      }
      else
      {
         m_price0 = MathMax(m_price0, iHigh(_Symbol, _Period, iBarShift(_Symbol, _Period, new_time)));
      }
      if(m_price0 != old_price0)
      {
         m_time0 = new_time;
         string obj_name = m_name + (m_is_test ? "_Test" : "");
         if(CheckObjectExists(obj_name) && ObjectMove(0, obj_name, 1, m_time0, m_price0))
         {
            Log("صفر مادر آپدیت شد: صفر=" + DoubleToString(m_price0, _Digits) + ", زمان=" + TimeToString(new_time));
            if(InpVisualDebug)
            {
               string line_name = "Debug_HLine_MotherZero_" + TimeToString(new_time) + (m_is_test ? "_Test" : "");
               if(ObjectCreate(0, line_name, OBJ_HLINE, 0, 0, m_price0))
               {
                  ObjectSetInteger(0, line_name, OBJPROP_COLOR, clrGray);
                  ObjectSetInteger(0, line_name, OBJPROP_STYLE, STYLE_DOT);
                  CheckObjectExists(line_name);
               }
            }
            return true;
         }
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
      Log("مادر فیکس شد (عبور قیمت): صفر=" + DoubleToString(m_price0, _Digits) + ", زمان=" + TimeToString(TimeCurrent()));

      // محاسبه و ذخیره قیمت سطح شکست نهایی (فقط سطح 250%)
      double target_level = 250.0;
      bool level_found = false;
      for(int i = 0; i < ArraySize(m_levels); i++)
      {
         if(MathAbs(m_levels[i] - target_level) < 0.01) // بررسی وجود سطح 250%
         {
            level_found = true;
            if(m_direction == LONG)
               m_breakout_failure_price = m_price100 + (m_price100 - m_price0) * (target_level / 100.0);
            else // SHORT
               m_breakout_failure_price = m_price100 - (m_price0 - m_price100) * (target_level / 100.0);
            Log("سطح شکست نهایی مادر در قیمت " + DoubleToString(m_breakout_failure_price, _Digits) + " محاسبه شد (سطح " + DoubleToString(target_level, 1) + "%)");
            break;
         }
      }
      if(!level_found)
      {
         Log("هشدار: سطح 250% در InpMotherLevels یافت نشد. سطح شکست محاسبه نشد.");
         m_breakout_failure_price = 0.0;
      }

      if(InpVisualDebug)
      {
         string arrow_name = "Debug_Arrow_MotherFix_" + TimeToString(TimeCurrent()) + (m_is_test ? "_Test" : "");
         if(ObjectCreate(0, arrow_name, m_direction == LONG ? OBJ_ARROW_UP : OBJ_ARROW_DOWN, 0, TimeCurrent(), current_price))
         {
            ObjectSetInteger(0, arrow_name, OBJPROP_COLOR, m_direction == LONG ? clrLimeGreen : clrMagenta);
            CheckObjectExists(arrow_name);
         }
         string label_name = "Debug_Label_MotherFix_" + TimeToString(TimeCurrent()) + (m_is_test ? "_Test" : "");
         if(ObjectCreate(0, label_name, OBJ_TEXT, 0, TimeCurrent(), m_price0))
         {
            ObjectSetString(0, label_name, OBJPROP_TEXT, "مادر فیکس شد: صفر=" + DoubleToString(m_price0, _Digits));
            ObjectSetInteger(0, label_name, OBJPROP_COLOR, clrWhite);
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
   bool fix_condition = (m_direction == LONG && iClose(_Symbol, _Period, 1) >= level_50) ||
                        (m_direction == SHORT && iClose(_Symbol, _Period, 1) <= level_50);
   if(fix_condition)
   {
      m_is_fixed = true;
      Log("مادر فیکس شد (کلوز کندل): صفر=" + DoubleToString(m_price0, _Digits) + ", زمان=" + TimeToString(TimeCurrent()));

      // محاسبه و ذخیره قیمت سطح شکست نهایی (فقط سطح 250%)
      double target_level = 250.0;
      bool level_found = false;
      for(int i = 0; i < ArraySize(m_levels); i++)
      {
         if(MathAbs(m_levels[i] - target_level) < 0.01) // بررسی وجود سطح 250%
         {
            level_found = true;
            if(m_direction == LONG)
               m_breakout_failure_price = m_price100 + (m_price100 - m_price0) * (target_level / 100.0);
            else // SHORT
               m_breakout_failure_price = m_price100 - (m_price0 - m_price100) * (target_level / 100.0);
            Log("سطح شکست نهایی مادر در قیمت " + DoubleToString(m_breakout_failure_price, _Digits) + " محاسبه شد (سطح " + DoubleToString(target_level, 1) + "%)");
            break;
         }
      }
      if(!level_found)
      {
         Log("هشدار: سطح 250% در InpMotherLevels یافت نشد. سطح شکست محاسبه نشد.");
         m_breakout_failure_price = 0.0;
      }

      if(InpVisualDebug)
      {
         string arrow_name = "Debug_Arrow_MotherFix_" + TimeToString(TimeCurrent()) + (m_is_test ? "_Test" : "");
         if(ObjectCreate(0, arrow_name, m_direction == LONG ? OBJ_ARROW_UP : OBJ_ARROW_DOWN, 0, TimeCurrent(), iClose(_Symbol, _Period, 1)))
         {
            ObjectSetInteger(0, arrow_name, OBJPROP_COLOR, m_direction == LONG ? clrLimeGreen : clrMagenta);
            CheckObjectExists(arrow_name);
         }
         string label_name = "Debug_Label_MotherFix_" + TimeToString(TimeCurrent()) + (m_is_test ? "_Test" : "");
         if(ObjectCreate(0, label_name, OBJ_TEXT, 0, TimeCurrent(), m_price0))
         {
            ObjectSetString(0, label_name, OBJPROP_TEXT, "مادر فیکس شد: صفر=" + DoubleToString(m_price0, _Digits));
            ObjectSetInteger(0, label_name, OBJPROP_COLOR, clrWhite);
         }
      }
      return true;
   }
   return false;
}
bool CheckBreakoutFailure(double current_price)
{
   if(m_breakout_failure_price == 0.0 || !m_is_fixed) return false;

   bool fail_condition = (m_direction == LONG && current_price >= m_breakout_failure_price) ||
                         (m_direction == SHORT && current_price <= m_breakout_failure_price);

   if(fail_condition)
   {
      Log("ساختار شکست خورد: عبور از سطح نهایی مادر: قیمت=" + DoubleToString(current_price, _Digits) + ", سطح شکست=" + DoubleToString(m_breakout_failure_price, _Digits) + ", زمان=" + TimeToString(TimeCurrent()));
      if(InpVisualDebug)
      {
         string arrow_name = "Debug_Arrow_BreakoutFail_" + TimeToString(TimeCurrent()) + (m_is_test ? "_Test" : "");
         if(ObjectCreate(0, arrow_name, m_direction == LONG ? OBJ_ARROW_UP : OBJ_ARROW_DOWN, 0, TimeCurrent(), current_price))
         {
            ObjectSetInteger(0, arrow_name, OBJPROP_COLOR, clrRed);
            CheckObjectExists(arrow_name);
         }
         string label_name = "Debug_Label_BreakoutFail_" + TimeToString(TimeCurrent()) + (m_is_test ? "_Test" : "");
         if(ObjectCreate(0, label_name, OBJ_TEXT, 0, TimeCurrent(), current_price))
         {
            double max_level_value = 0.0;
            for(int i = 0; i < ArraySize(m_levels); i++)
            {
               if(m_levels[i] > 100.0 && m_levels[i] > max_level_value)
                  max_level_value = m_levels[i];
            }
            ObjectSetString(0, label_name, OBJPROP_TEXT, "ساختار شکست خورد: عبور از سطح " + DoubleToString(max_level_value, 1) + "% مادر");
            ObjectSetInteger(0, label_name, OBJPROP_COLOR, clrRed);
            CheckObjectExists(label_name);
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
         Log("ساختار شکست خورد: لنگرگاه مادر سوراخ شد: قیمت=" + DoubleToString(current_price, _Digits) + ", زمان=" + TimeToString(TimeCurrent()));
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
   ENUM_DIRECTION m_direction; // جهت‌گیری فرزند (جدید)
   // متغیرهای جدید برای شکست تأییدشده
   bool m_breakout_triggered;
   datetime m_breakout_candle_time;
   double m_breakout_candle_high;
   double m_breakout_candle_low;
   int m_breakout_candle_count;
   datetime m_fixation_time;
   double   m_fixation_price;
   datetime m_breakout_time;
   double   m_breakout_price;
   
   void Log(string message)
   {
      if(InpEnableLog)
         Print(TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES | TIME_SECONDS) + ": " + message);
   }

   bool GetChild2BreakLevels(double &min_level, double &max_level)
   {
      min_level = 0.0;
      max_level = 0.0;
      if(InpChild2BreakLevels != "")
      {
         string temp_levels[];
         int count = StringSplit(InpChild2BreakLevels, StringGetCharacter(",", 0), temp_levels);
         if(count >= 2)
         {
            min_level = StringToDouble(temp_levels[0]);
            max_level = StringToDouble(temp_levels[1]);
            if(min_level >= 0 && max_level > min_level)
               return true;
         }
         Log("خطا: سطوح شکست فرزند دوم نامعتبر است: " + InpChild2BreakLevels);
      }
      if(m_parent_mother != NULL && m_parent_mother.GetLevelsCount() >= 2)
      {
         min_level = m_parent_mother.GetLevel(m_parent_mother.GetLevelsCount() - 2);
         max_level = m_parent_mother.GetLevel(m_parent_mother.GetLevelsCount() - 1);
         return true;
      }
      Log("خطا: نمی‌توان سطوح شکست فرزند دوم را از InpMotherLevels استخراج کرد");
      return false;
   }

public:
 CChildFibo(string name, color clr, string levels, CMotherFibo* mother, bool is_success_child2, bool is_test)
      : CBaseFibo(name, clr, levels, is_test)
   {
      m_is_fixed = false;
      m_is_success_child2 = is_success_child2;
      m_parent_mother = mother;
      m_direction = mother != NULL ? mother.GetDirection() : LONG; // مقداردهی اولیه جهت‌گیری
      m_breakout_triggered = false;
      m_breakout_candle_time = 0;
      m_breakout_candle_high = 0.0;
      m_breakout_candle_low = 0.0;
      m_breakout_candle_count = 0;
   }
//+------------------------------------------------------------------+
//| CChildFibo::Draw (نسخه اصلاح شده و صحیح)                         |
//+------------------------------------------------------------------+
virtual bool Draw() override
{
   string obj_name = m_name + (m_is_test ? "_Test" : "");
   ObjectDelete(0, obj_name);
   
   // قانون ساده است: نقطه اول همیشه 100% و نقطه دوم همیشه 0% است.
   // خود متغیرها از قبل می‌دانند کدام بالا و کدام پایین است.
   // پس نیاز به هیچ منطق اضافی برای جهت‌گیری نیست.
   if(!ObjectCreate(0, obj_name, OBJ_FIBO, 0, m_time100, m_price100, m_time0, m_price0))
   {
      Print("خطا در ایجاد شیء فیبوناچی فرزند: ", obj_name);
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
   
   // لاگ برای دیباگ
   Log("رسم فیبوناچی فرزند: نام=" + obj_name +
       ", نقطه 100 (زمان=" + TimeToString(m_time100) + ", قیمت=" + DoubleToString(m_price100, _Digits) + ")" +
       ", نقطه 0 (زمان=" + TimeToString(m_time0) + ", قیمت=" + DoubleToString(m_price0, _Digits) + ")");
   
   ChartRedraw(0);
   Sleep(50);
   return CheckObjectExists(obj_name);
}



   bool Initialize(datetime current_time)
   {
      if(m_parent_mother == NULL) return false;
      m_time0 = m_parent_mother.GetTime0();
      m_price0 = m_parent_mother.GetPrice0();
      if(m_parent_mother.GetDirection() == LONG)
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
         Log("فرزند " + (StringFind(m_name, "Child1") >= 0 ? "اول" : (m_is_success_child2 ? "دوم (موفق)" : "دوم (ناموفق)")) +
             " متولد شد: صد=" + DoubleToString(m_price100, _Digits) + ", صفر=" + DoubleToString(m_price0, _Digits) +
             ", زمان=" + TimeToString(m_time100));
         if(InpVisualDebug)
         {
            string arrow_name = "Debug_Arrow_" + (StringFind(m_name, "Child1") >= 0 ? "Child1Birth_" : "Child2Birth_") +
                                TimeToString(m_time100) + (m_is_test ? "_Test" : "");
            if(ObjectCreate(0, arrow_name, m_parent_mother.GetDirection() == LONG ? OBJ_ARROW_UP : OBJ_ARROW_DOWN, 0, m_time100, m_price100))
            {
               ObjectSetInteger(0, arrow_name, OBJPROP_COLOR, StringFind(m_name, "Child1") >= 0 ? (m_parent_mother.GetDirection() == LONG ? clrCyan : clrPink) :
                                                               (m_parent_mother.GetDirection() == LONG ? clrDarkGreen : clrDarkRed));
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
   double old_price100 = m_price100;
   if(m_direction == LONG)
   {
      m_price100 = MathMax(m_price100, iHigh(_Symbol, _Period, iBarShift(_Symbol, _Period, new_time)));
   }
   else
   {
      m_price100 = MathMin(m_price100, iLow(_Symbol, _Period, iBarShift(_Symbol, _Period, new_time)));
   }
   if(m_price100 != old_price100)
   {
      m_time100 = new_time;
      string obj_name = m_name + (m_is_test ? "_Test" : "");
      if(CheckObjectExists(obj_name) && ObjectMove(0, obj_name, 0, m_time100, m_price100))
      {
         Log("صد فرزند " + (StringFind(m_name, "Child1") >= 0 ? "اول" : (m_is_success_child2 ? "دوم (موفق)" : "دوم (ناموفق)")) +
             " آپدیت شد: صد=" + DoubleToString(m_price100, _Digits) + ", زمان=" + TimeToString(new_time) +
             ", جهت=" + (m_direction == LONG ? "Long" : "Short"));
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
         // بازرسم فیبوناچی برای اطمینان از صحت نمایش
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
      bool fix_condition = (m_parent_mother.GetDirection() == LONG && current_price <= level_50) ||
                           (m_parent_mother.GetDirection() == SHORT && current_price >= level_50);
      if(fix_condition)
      {
         m_is_fixed = true;
         
          // <<-- اضافه شد: ثبت زمان و قیمت فیکس شدن -->>
          m_fixation_time = TimeCurrent();
         m_fixation_price = current_price;
   
         Log("فرزند اول فیکس شد: صد=" + DoubleToString(m_price100, _Digits) + ", زمان=" + TimeToString(TimeCurrent()));
         if(InpVisualDebug)
         {
            string arrow_name = "Debug_Arrow_Child1Fix_" + TimeToString(TimeCurrent()) + (m_is_test ? "_Test" : "");
            if(ObjectCreate(0, arrow_name, m_parent_mother.GetDirection() == LONG ? OBJ_ARROW_DOWN : OBJ_ARROW_UP, 0, TimeCurrent(), current_price))
            {
               ObjectSetInteger(0, arrow_name, OBJPROP_COLOR, m_parent_mother.GetDirection() == LONG ? clrGreen : clrRed);
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
         bool trigger_condition = (m_parent_mother.GetDirection() == LONG && current_price > m_price100) ||
                                 (m_parent_mother.GetDirection() == SHORT && current_price < m_price100);
         if(trigger_condition)
         {
         m_breakout_time = TimeCurrent();
        m_breakout_price = current_price;
            Log("فرزند دوم (موفق) فعال شد: عبور از صد فرزند اول: قیمت=" + DoubleToString(current_price, _Digits) + ", زمان=" + TimeToString(TimeCurrent()));
            return true;
         }
      }
      return false;
   }

 bool CheckFailure(double current_price)
{
   if(m_is_fixed || m_parent_mother == NULL) return false;
   
   if(InpChildBreakMode == PRICE_CROSSS)
   {
      double mother_100_level = m_parent_mother.GetPrice100();
      bool fail_condition = (m_parent_mother.GetDirection() == LONG && current_price > mother_100_level) ||
                            (m_parent_mother.GetDirection() == SHORT && current_price < mother_100_level);
      if(fail_condition)
      {
         Log("فرزند " + (StringFind(m_name, "Child1") >= 0 ? "اول" : (m_is_success_child2 ? "دوم (موفق)" : "دوم (ناموفق)")) +
             " شکست خورد: قیمت=" + DoubleToString(current_price, _Digits) + ", زمان=" + TimeToString(TimeCurrent()));
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
   else if(InpChildBreakMode == CONFIRMED_BREAK)
   {
      // اگر شکست اولیه هنوز فعال نشده، بررسی کلوز کندل
      if(!m_breakout_triggered)
      {
         bool close_condition = (m_parent_mother.GetDirection() == LONG && iClose(_Symbol, _Period, 1) >= m_parent_mother.GetPrice100()) ||
                               (m_parent_mother.GetDirection() == SHORT && iClose(_Symbol, _Period, 1) <= m_parent_mother.GetPrice100());
         if(close_condition)
         {
            m_breakout_triggered = true;
            m_breakout_candle_time = iTime(_Symbol, _Period, 1);
            m_breakout_candle_high = iHigh(_Symbol, _Period, 1);
            m_breakout_candle_low = iLow(_Symbol, _Period, 1);
            m_breakout_candle_count = 0;
            Log("شکست اولیه سطح 100% مادر: قیمت کلوز=" + DoubleToString(iClose(_Symbol, _Period, 1), _Digits) +
                ", High=" + DoubleToString(m_breakout_candle_high, _Digits) +
                ", Low=" + DoubleToString(m_breakout_candle_low, _Digits) +
                ", زمان=" + TimeToString(m_breakout_candle_time));
         }
      }
      // اگر شکست اولیه فعال شده، بررسی کندل‌های بعدی
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
         bool confirm_condition = (m_parent_mother.GetDirection() == LONG && iHigh(_Symbol, _Period, 1) >= m_breakout_candle_high) ||
                                 (m_parent_mother.GetDirection() == SHORT && iLow(_Symbol, _Period, 1) <= m_breakout_candle_low);
         if(confirm_condition)
         {
            Log("فرزند " + (StringFind(m_name, "Child1") >= 0 ? "اول" : (m_is_success_child2 ? "دوم (موفق)" : "دوم (ناموفق)")) +
                " شکست خورد (تأییدشده): قیمت=" + DoubleToString(iClose(_Symbol, _Period, 1), _Digits) +
                ", کندل شماره=" + IntegerToString(m_breakout_candle_count) +
                ", زمان=" + TimeToString(TimeCurrent()));
            if(InpVisualDebug)
            {
               string arrow_name = "Debug_Arrow_ChildFail_" + TimeToString(TimeCurrent()) + (m_is_test ? "_Test" : "");
               if(ObjectCreate(0, arrow_name, m_parent_mother.GetDirection() == LONG ? OBJ_ARROW_UP : OBJ_ARROW_DOWN, 0, TimeCurrent(), iClose(_Symbol, _Period, 1)))
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


   // <<-- اضافه شد: تابع اصلی برای خروجی گرفتن از تمام داده‌های کلیدی این فرزند -->>
   SFibonacciEventData GetEventData()
   {
      SFibonacciEventData data;
      
      // پر کردن اطلاعاتی که ثبت کردیم
      data.child1_fix_time = m_fixation_time;
      data.child1_fix_price = m_fixation_price;
      data.child1_breakout_time = m_breakout_time;
      data.child1_breakout_price = m_breakout_price;

      // پر کردن رشته سطوح فیبوناچی
      string result = "";
      for(int i = 0; i < ArraySize(m_levels); i++)
      {
         double level_price = m_price100 + (m_price0 - m_price100) * (m_levels[i] / 100.0);
         result += "L" + (string)m_levels[i] + ":" + DoubleToString(level_price, _Digits) + ";";
      }
      data.child2_levels_string = result;
      
      return data;
   }

//+------------------------------------------------------------------+
//| CChildFibo::CheckSuccessChild2 (نسخه کامل و نهایی)                |
//+------------------------------------------------------------------+
bool CheckSuccessChild2(double current_price)
{
    // این شرط که فقط برای فرزند موفق بود حذف شد تا برای هر دو مسیر کار کند
    if (m_parent_mother == NULL) return false; 
    
    string temp_levels[];
    int count = StringSplit(InpGoldenZone, StringGetCharacter(",", 0), temp_levels);
    if (count < 2)
    {
        Log("خطا: ناحیه طلایی نامعتبر است: " + InpGoldenZone);
        return false;
    }
    
    double level_1 = StringToDouble(temp_levels[0]) / 100.0;
    double level_2 = StringToDouble(temp_levels[1]) / 100.0;
    
    if (level_1 >= level_2)
    {
        Log("خطا: ناحیه طلایی نامعتبر است، حداقل باید کوچکتر از حداکثر باشد: " + InpGoldenZone);
        return false;
    }
    
    // محاسبه قیمت در دو سطح ناحیه طلایی
    double price_level_1 = m_price100 + (m_price0 - m_price100) * level_1;
    double price_level_2 = m_price100 + (m_price0 - m_price100) * level_2;
    
    // پیدا کردن کران بالا و پایین واقعی ناحیه با MathMin و MathMax
    double zone_lower_bound = MathMin(price_level_1, price_level_2);
    double zone_upper_bound = MathMax(price_level_1, price_level_2);
    
    // حالا شرط رو خیلی ساده و تمیز بررسی می‌کنیم
    bool success_condition = (current_price >= zone_lower_bound && current_price <= zone_upper_bound);
    
    if (success_condition)
    {
        Log("فرزند دوم وارد ناحیه طلایی شد: قیمت=" + DoubleToString(current_price, _Digits) + ", زمان=" + TimeToString(TimeCurrent()));
        if (InpVisualDebug)
        {
            string rect_name = "Debug_Rect_GoldenZone_" + TimeToString(TimeCurrent()) + (m_is_test ? "_Test" : "");
            if (ObjectCreate(0, rect_name, OBJ_RECTANGLE, 0, TimeCurrent(), zone_lower_bound, TimeCurrent() + PeriodSeconds(), zone_upper_bound))
            {
                ObjectSetInteger(0, rect_name, OBJPROP_COLOR, clrGoldenrod);
                ObjectSetInteger(0, rect_name, OBJPROP_BGCOLOR, clrGoldenrod);
                ObjectSetInteger(0, rect_name, OBJPROP_FILL, true);
                ObjectSetInteger(0, rect_name, OBJPROP_ZORDER, -1);
                CheckObjectExists(rect_name);
            }
            string arrow_name = "Debug_Arrow_Signal_" + TimeToString(TimeCurrent()) + (m_is_test ? "_Test" : "");
            if (ObjectCreate(0, arrow_name, m_parent_mother.GetDirection() == LONG ? OBJ_ARROW_UP : OBJ_ARROW_DOWN, 0, TimeCurrent(), current_price))
            {
                ObjectSetInteger(0, arrow_name, OBJPROP_COLOR, clrGold);
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
         Log("ساختار شکست خورد: لنگرگاه مادر سوراخ شد: قیمت=" + DoubleToString(current_price, _Digits) + ", زمان=" + TimeToString(TimeCurrent()));
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

 bool CheckFailureChild2OnNewBar()
{
   if(m_parent_mother == NULL) return false;
   if(!m_is_success_child2)
   {
      double target_level = 250.0;
      bool level_found = false;
      for(int i = 0; i < m_parent_mother.GetLevelsCount(); i++)
      {
         if(MathAbs(m_parent_mother.GetLevel(i) - target_level) < 0.01) // بررسی وجود سطح 250%
         {
            level_found = true;
            double break_level;
            if(m_parent_mother.GetDirection() == LONG)
               break_level = m_parent_mother.GetPrice100() + (m_parent_mother.GetPrice100() - m_parent_mother.GetPrice0()) * (target_level / 100.0);
            else // SHORT
               break_level = m_parent_mother.GetPrice100() - (m_parent_mother.GetPrice0() - m_parent_mother.GetPrice100()) * (target_level / 100.0);
            
            bool break_condition = false;
            if(InpStructureBreakMode == PRICE_CROSS1)
            {
               break_condition = (m_parent_mother.GetDirection() == LONG && iHigh(_Symbol, _Period, 1) >= break_level) ||
                                 (m_parent_mother.GetDirection() == SHORT && iLow(_Symbol, _Period, 1) <= break_level);
            }
            else if(InpStructureBreakMode == CANDLE_CLOSE1)
            {
               break_condition = (m_parent_mother.GetDirection() == LONG && iClose(_Symbol, _Period, 1) >= break_level && iOpen(_Symbol, _Period, 0) >= break_level) ||
                                 (m_parent_mother.GetDirection() == SHORT && iClose(_Symbol, _Period, 1) <= break_level && iOpen(_Symbol, _Period, 0) <= break_level);
            }
            if(break_condition)
            {
               Log("ساختار شکست خورد: عبور از سطح " + DoubleToString(target_level, 1) + "% مادر: قیمت=" + DoubleToString(iClose(_Symbol, _Period, 1), _Digits) + 
                   ", سطح شکست=" + DoubleToString(break_level, _Digits) + ", زمان=" + TimeToString(TimeCurrent()));
               if(InpVisualDebug)
               {
                  string label_name = "Debug_Label_StructureFail_" + TimeToString(TimeCurrent()) + (m_is_test ? "_Test" : "");
                  if(ObjectCreate(0, label_name, OBJ_TEXT, 0, TimeCurrent(), iClose(_Symbol, _Period, 1)))
                  {
                     ObjectSetString(0, label_name, OBJPROP_TEXT, "ساختار شکست خورد: عبور از سطح " + DoubleToString(target_level, 1) + "% مادر");
                     ObjectSetInteger(0, label_name, OBJPROP_COLOR, clrRed);
                     CheckObjectExists(label_name);
                  }
                  string arrow_name = "Debug_Arrow_StructureFail_" + TimeToString(TimeCurrent()) + (m_is_test ? "_Test" : "");
                  if(ObjectCreate(0, arrow_name, m_parent_mother.GetDirection() == LONG ? OBJ_ARROW_UP : OBJ_ARROW_DOWN, 0, TimeCurrent(), iClose(_Symbol, _Period, 1)))
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
      if(!level_found)
      {
         Log("هشدار: سطح 250% در InpMotherLevels یافت نشد. بررسی شکست انجام نشد.");
      }
   }
   return false;
}
   bool CheckChild2Trigger(double current_price)
   {
      if(m_is_success_child2 || m_parent_mother == NULL) return false;
      double min_level, max_level;
      if(!GetChild2BreakLevels(min_level, max_level)) return false;
      double break_level_min = m_parent_mother.GetPrice100() + (m_parent_mother.GetPrice0() - m_parent_mother.GetPrice100()) * min_level / 100.0;
      double break_level_max = m_parent_mother.GetPrice100() + (m_parent_mother.GetPrice0() - m_parent_mother.GetPrice100()) * max_level / 100.0;
      bool trigger_condition = (m_parent_mother.GetDirection() == LONG && current_price >= break_level_min && current_price <= break_level_max) ||
                               (m_parent_mother.GetDirection() == SHORT && current_price <= break_level_min && current_price >= break_level_max);
      if(trigger_condition)
      {
         Log("فرزند دوم (ناموفق) فعال شد: قیمت=" + DoubleToString(current_price, _Digits) + ", زمان=" + TimeToString(TimeCurrent()));
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
   bool m_is_visible;

   void Log(string message)
   {
      if(InpEnableLog)
         CStructureManager::AddLog(m_id + ": " + message);
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
      m_is_visible = false;
   }

   void Reset()
   {
      Destroy();
      m_state = SEARCHING;
      Log("تحلیلگر ریست شد و آماده جستجوی جدید است.");
   }

   bool Initialize()
   {
      SFractal fractal;
      ENUM_TIMEFRAMES fractal_tf = PERIOD_CURRENT;
      if(m_direction == LONG)
         m_fractal_finder.FindRecentHigh(TimeCurrent(), InpFractalLookback, InpFractalPeers, fractal_tf, fractal);
      else
         m_fractal_finder.FindRecentLow(TimeCurrent(), InpFractalLookback, InpFractalPeers, fractal_tf, fractal);

      if(fractal.price == 0.0 || fractal.time == 0)
      {
         return false;
      }

      m_mother = new CMotherFibo(m_id + "_Mother", InpMotherColor, InpMotherLevels, m_direction, m_is_test);
      if(m_mother == NULL)
      {
         Log("خطا: نمی‌توان مادر را ایجاد کرد");
         return false;
      }

      m_mother.SetVisibility(m_is_visible);
      if(m_mother.Initialize(fractal, TimeCurrent()))
      {
         m_state = MOTHER_ACTIVE;
         Log("ساختار در حالت مادر فعال");
         return true;
      }
      delete m_mother;
      m_mother = NULL;
      return false;
   }

   bool TryUpdateMotherFractal()
   {
      if(m_mother == NULL || m_mother.IsFixed())
         return false;

      datetime current_mother_time = m_mother.GetTime100();
      SFractal new_fractal;
      ENUM_TIMEFRAMES fractal_tf = PERIOD_CURRENT;
      if(m_direction == LONG)
         m_fractal_finder.FindRecentHigh(TimeCurrent(), InpFractalLookback, InpFractalPeers, fractal_tf, new_fractal);
      else
         m_fractal_finder.FindRecentLow(TimeCurrent(), InpFractalLookback, InpFractalPeers, fractal_tf, new_fractal);

      if(new_fractal.price != 0.0 && new_fractal.time > current_mother_time)
      {
         Log("نگهبان مادر: فراکتال بی‌اعتبار در " + TimeToString(current_mother_time) + " شناسایی شد.");
         Log("--> فراکتال جدید در " + TimeToString(new_fractal.time) + " یافت شد. در حال ریست کردن مادر...");

         m_mother.Delete();
         delete m_mother;
         m_mother = NULL;

         if(InpVisualDebug && m_is_visible)
            ClearDebugObjects(m_is_test);

         m_mother = new CMotherFibo(m_id + "_Mother", InpMotherColor, InpMotherLevels, m_direction, m_is_test);
         if(m_mother == NULL)
         {
            Log("خطای حیاتی: ایجاد مادر جدید پس از ریست ناموفق بود.");
            m_state = FAILED;
            return false;
         }

         m_mother.SetVisibility(m_is_visible);
         if(m_mother.Initialize(new_fractal, TimeCurrent()))
         {
            Log("مادر با موفقیت بر اساس فراکتال جدید در " + DoubleToString(new_fractal.price, _Digits) + " ریست شد.");
            return true;
         }
         else
         {
            Log("خطا: راه‌اندازی مادر جدید پس از ریست ناموفق بود.");
            delete m_mother;
            m_mother = NULL;
            m_state = FAILED;
            return false;
         }
      }
      return false;
   }

   bool UpdateOnTick(double current_price, datetime current_time)
   {
      if(m_state == SEARCHING)
      {
         return Initialize();
      }
      else if(m_state == MOTHER_ACTIVE || m_state == CHILD1_ACTIVE)
      {
         if(m_mother != NULL && m_mother.CheckBreakoutFailure(current_price))
         {
            m_state = FAILED;
            Log("ساختار شکست خورد: عبور از سطح نهایی مادر");
            return false;
         }
      }

      if(m_state == MOTHER_ACTIVE)
      {
         if(TryUpdateMotherFractal()) return true;
         if(m_mother != NULL && m_mother.CheckStructureFailure(current_price))
         {
            m_state = FAILED;
            Log("ساختار شکست خورد: لنگرگاه مادر سوراخ شد");
            return false;
         }
         if(m_mother != NULL && !m_mother.UpdateOnTick(current_time)) return false;
         if(m_mother != NULL)
         {
            if(InpMotherFixMode == PRICE_CROSS && m_mother.CheckFixingPriceCross(current_price))
            {
               m_child1 = new CChildFibo(m_id + "_Child1", InpChild1Color, InpChildLevels, m_mother, false, m_is_test);
               if(m_child1 == NULL)
               {
                  Log("خطا: نمی‌توان فرزند اول را ایجاد کرد");
                  m_state = FAILED;
                  return false;
               }
               m_child1.SetVisibility(m_is_visible);
               if(!m_child1.Initialize(current_time))
               {
                  Log("خطا: راه‌اندازی فرزند اول ناموفق بود");
                  delete m_child1;
                  m_child1 = NULL;
                  m_state = FAILED;
                  return false;
               }
               m_state = CHILD1_ACTIVE;
               Log("ساختار به فرزند اول فعال تغییر کرد");
            }
            else if(InpMotherFixMode == CANDLE_CLOSE && m_mother.CheckFixingCandleClose())
            {
               m_child1 = new CChildFibo(m_id + "_Child1", InpChild1Color, InpChildLevels, m_mother, false, m_is_test);
               if(m_child1 == NULL)
               {
                  Log("خطا: نمی‌توان فرزند اول را ایجاد کرد");
                  m_state = FAILED;
                  return false;
               }
               m_child1.SetVisibility(m_is_visible);
               if(!m_child1.Initialize(current_time))
               {
                  Log("خطا: راه‌اندازی فرزند اول ناموفق بود");
                  delete m_child1;
                  m_child1 = NULL;
                  m_state = FAILED;
                  return false;
               }
               m_state = CHILD1_ACTIVE;
               Log("ساختار به فرزند اول فعال تغییر کرد");
            }
         }
      }
      else if(m_state == CHILD1_ACTIVE)
      {
         if(m_mother != NULL && m_mother.CheckStructureFailure(current_price))
         {
            m_state = FAILED;
            Log("ساختار شکست خورد: لنگرگاه مادر سوراخ شد");
            return false;
         }
         if(m_child1 != NULL && m_child1.CheckFailure(current_price))
         {
            m_child1.Delete();
            delete m_child1;
            m_child1 = NULL;
            m_child2 = new CChildFibo(m_id + "_FailureChild2", InpChild2Color, InpChildLevels, m_mother, false, m_is_test);
            if(m_child2 == NULL)
            {
               Log("خطا: نمی‌توان فرزند دوم (ناموفق) را ایجاد کرد");
               m_state = FAILED;
               return false;
            }
            m_child2.SetVisibility(m_is_visible);
            if(!m_child2.Initialize(current_time))
            {
               Log("خطا: راه‌اندازی فرزند دوم (ناموفق) ناموفق بود");
               delete m_child2;
               m_child2 = NULL;
               m_state = FAILED;
               return false;
            }
            m_state = CHILD2_ACTIVE;
            Log("فرزند اول شکست خورد، ساختار به فرزند دوم (ناموفق) تغییر کرد");
         }
         else if(m_child1 != NULL && m_child1.UpdateOnTick(current_time))
         {
            if(m_child1.IsFixed() && m_child1.CheckChild1TriggerChild2(current_price))
            {
               SFibonacciEventData event_data = m_child1.GetEventData();
               datetime fix_time = event_data.child1_fix_time;
               datetime break_time = event_data.child1_breakout_time;
               double break_price = event_data.child1_breakout_price;

               double new_zero_price = 0;
               datetime new_zero_time = 0;

               int fix_bar = iBarShift(_Symbol, PERIOD_CURRENT, fix_time);
               int break_bar = iBarShift(_Symbol, PERIOD_CURRENT, break_time);

               if(m_direction == LONG)
               {
                  new_zero_price = iLow(_Symbol, PERIOD_CURRENT, break_bar);
                  new_zero_time = break_time;
                  for(int i = break_bar; i <= fix_bar; i++)
                  {
                     double bar_low = iLow(_Symbol, PERIOD_CURRENT, i);
                     if(bar_low < new_zero_price)
                     {
                        new_zero_price = bar_low;
                        new_zero_time = iTime(_Symbol, PERIOD_CURRENT, i);
                     }
                  }
               }
               else // SHORT
               {
                  new_zero_price = iHigh(_Symbol, PERIOD_CURRENT, break_bar);
                  new_zero_time = break_time;
                  for(int i = break_bar; i <= fix_bar; i++)
                  {
                     double bar_high = iHigh(_Symbol, PERIOD_CURRENT, i);
                     if(bar_high > new_zero_price)
                     {
                        new_zero_price = bar_high;
                        new_zero_time = iTime(_Symbol, PERIOD_CURRENT, i);
                     }
                  }
               }

               Log("نقطه صفر جدید برای فرزند دوم موفق محاسبه شد: قیمت=" + DoubleToString(new_zero_price, _Digits));

               m_child1.Delete();
               delete m_child1;
               m_child1 = NULL;

               m_child2 = new CChildFibo(m_id + "_SuccessChild2", InpChild2Color, InpChildLevels, m_mother, true, m_is_test);
               if(m_child2 == NULL)
               {
                  Log("خطا: نمی‌توان فرزند دوم (موفق) را ایجاد کرد");
                  m_state = FAILED;
                  return false;
               }
               m_child2.SetVisibility(m_is_visible);
               m_child2.SetPoints(new_zero_time, new_zero_price, break_time, break_price);
               if(!m_child2.Draw())
               {
                  Log("خطا: رسم فرزند دوم (موفق) ناموفق بود");
                  delete m_child2;
                  m_child2 = NULL;
                  m_state = FAILED;
                  return false;
               }
               m_state = CHILD2_ACTIVE;
               Log("فرزند اول موفق شد، ساختار به فرزند دوم (موفق) با نقطه صفر اصلاح شده تغییر کرد");
            }
            else if(m_child1 != NULL)
            {
               m_child1.CheckFixing(current_price);
            }
         }
      }
      else if(m_state == CHILD2_ACTIVE)
      {
         if(m_mother != NULL && m_mother.CheckStructureFailure(current_price))
         {
            m_state = FAILED;
            Log("ساختار شکست خورد: لنگرگاه مادر سوراخ شد");
            return false;
         }
         if(m_child2 != NULL && m_child2.CheckFailureChild2OnTick(current_price))
         {
            m_state = FAILED;
            Log("ساختار شکست خورد: لنگرگاه فرزند دوم سوراخ شد");
            return false;
         }
         if(m_child2 != NULL && m_child2.IsSuccessChild2() && m_child2.CheckSuccessChild2(current_price))
         {
            m_state = COMPLETED;
            Log("ساختار کامل شد: فرزند دوم وارد ناحیه طلایی شد");
            return false;
         }
      }
      return true;
   }

   bool UpdateOnNewBar()
   {
      if(m_state == SEARCHING || m_state == FAILED || m_state == COMPLETED)
         return false;
      if(m_state == CHILD2_ACTIVE && m_child2 != NULL)
      {
         if(m_child2.CheckFailureChild2OnNewBar())
         {
            m_state = FAILED;
            Log("ساختار شکست خورد: عبور از سطح نهایی مادر");
            return false;
         }
      }
      return true;
   }

   SSignal GetSignal()
   {
      SSignal signal = {"", ""};
      if(m_state == CHILD2_ACTIVE && m_child2 != NULL && m_child2.IsSuccessChild2())
      {
         if(m_child2.CheckSuccessChild2(SymbolInfoDouble(_Symbol, SYMBOL_BID)))
         {
            signal.type = m_direction == LONG ? "Buy" : "Sell";
            signal.id = m_id;
         }
      }
      return signal;
   }

   bool IsActive()
   {
      return m_state != SEARCHING && m_state != FAILED && m_state != COMPLETED;
   }

   ENUM_STRUCTURE_STATE GetState() { return m_state; }
   ENUM_DIRECTION GetDirection() { return m_direction; }
   double GetMotherPrice0()
   {
      if(m_mother != NULL)
         return m_mother.GetPrice0();
      return 0.0;
   }

   void SetVisibility(bool visible)
   {
      if(m_is_visible == visible) return;
      m_is_visible = visible;
      if(m_mother != NULL) m_mother.SetVisibility(m_is_visible);
      if(m_child1 != NULL) m_child1.SetVisibility(m_is_visible);
      if(m_child2 != NULL) m_child2.SetVisibility(m_is_visible);
      if(m_is_visible && InpVisualDebug)
      {
         // اشیاء دیباگ در صورت نیاز دوباره رسم می‌شوند
      }
      else if(!m_is_visible && InpVisualDebug)
      {
         ClearDebugObjects(m_is_test);
      }
   }

   void Destroy()
   {
      if(m_child2 != NULL) { m_child2.Delete(); delete m_child2; m_child2 = NULL; }
      if(m_child1 != NULL) { m_child1.Delete(); delete m_child1; m_child1 = NULL; }
      if(m_mother != NULL) { m_mother.Delete(); delete m_mother; m_mother = NULL; }
      m_state = SEARCHING;
      if(InpVisualDebug)
         ClearDebugObjects(m_is_test);
   }
};

//+------------------------------------------------------------------+
//| کلاس CStructureManager: مدیریت تمام ساختارها                   |
//+------------------------------------------------------------------+
class CStructureManager
{
private:
   CFamily* m_long_analyzer;
   CFamily* m_short_analyzer;
   CFamily* m_active_family;
   ENUM_DIRECTION m_analysis_direction;
   CPanel* m_panel;
   CTestPanel* m_test_panel;
   int m_file_handle;

   void Log(string message)
   {
      if(InpEnableLog)
      {
         if(m_file_handle == INVALID_HANDLE)
            m_file_handle = FileOpen(InpLogFilePath, FILE_WRITE | FILE_TXT | FILE_COMMON);
         if(m_file_handle != INVALID_HANDLE)
         {
            FileWrite(m_file_handle, TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES | TIME_SECONDS) + ": " + message);
            FileFlush(m_file_handle);
         }
         Print(message);
      }
   }

public:
   static void AddLog(string message)
   {
      if(InpEnableLog)
      {
         int handle = FileOpen(InpLogFilePath, FILE_WRITE | FILE_TXT | FILE_COMMON);
         if(handle != INVALID_HANDLE)
         {
            FileSeek(handle, 0, SEEK_END);
            FileWrite(handle, TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES | TIME_SECONDS) + ": " + message);
            FileFlush(handle);
            FileClose(handle);
         }
         Print(message);
      }
   }

   CStructureManager()
   {
      m_long_analyzer = NULL;
      m_short_analyzer = NULL;
      m_active_family = NULL;
      m_analysis_direction = DIRECTION_NONE;
      m_panel = NULL;
      m_test_panel = NULL;
      m_file_handle = INVALID_HANDLE;
   }

   bool HFiboOnInit()
   {
      if(InpShowPanelEa)
      {
         m_panel = new CPanel("HipoFibo_Panel", InpPanelCorner, InpPanelOffsetX, InpPanelOffsetY);
         if(m_panel == NULL || !m_panel.Create())
         {
            Log("خطا: نمی‌توان پنل اطلاعاتی را ایجاد کرد");
            delete m_panel;
            m_panel = NULL;
            return false;
         }
      }
      if(InpTestMode)
      {
         m_test_panel = new CTestPanel("HipoFibo_TestPanel", InpTestPanelCorner, InpTestPanelOffsetX, InpTestPanelOffsetY,
                                       InpTestPanelButtonColorLong, InpTestPanelButtonColorShort, InpTestPanelButtonColorStop, InpTestPanelBgColor);
         if(m_test_panel == NULL || !m_test_panel.Create())
         {
            Log("خطا: نمی‌توان پنل تست را ایجاد کرد");
            delete m_test_panel;
            m_test_panel = NULL;
            return false;
         }
      }
      m_long_analyzer = new CFamily("BG_Long", LONG, InpTestMode);
      m_short_analyzer = new CFamily("BG_Short", SHORT, InpTestMode);
      if(m_long_analyzer == NULL || m_short_analyzer == NULL)
      {
         Log("خطا: ایجاد تحلیل‌گرهای پس‌زمینه ناموفق بود.");
         return false;
      }
      Log("کتابخانه HipoFibonacci با تحلیل پس‌زمینه راه‌اندازی شد");
      return true;
   }

   void HFiboOnDeinit(const int reason)
   {
      if(m_long_analyzer != NULL) { m_long_analyzer.Destroy(); delete m_long_analyzer; m_long_analyzer = NULL; }
      if(m_short_analyzer != NULL) { m_short_analyzer.Destroy(); delete m_short_analyzer; m_short_analyzer = NULL; }
      if(m_active_family != NULL) { m_active_family.Destroy(); m_active_family = NULL; }
      if(m_panel != NULL) { m_panel.Destroy(); delete m_panel; m_panel = NULL; }
      if(m_test_panel != NULL) { m_test_panel.Destroy(); delete m_test_panel; m_test_panel = NULL; }
      if(m_file_handle != INVALID_HANDLE)
      {
         FileClose(m_file_handle);
         m_file_handle = INVALID_HANDLE;
      }
      Log("کتابخانه HipoFibonacci تخریب شد: دلیل=" + IntegerToString(reason));
   }

   void HFiboOnTick()
   {
      double current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      datetime current_time = TimeCurrent();
      if(m_analysis_direction == LONG && m_long_analyzer != NULL)
      {
         if(!m_long_analyzer.UpdateOnTick(current_price, current_time))
            m_long_analyzer.Reset();
      }
      else if(m_analysis_direction == SHORT && m_short_analyzer != NULL)
      {
         if(!m_short_analyzer.UpdateOnTick(current_price, current_time))
            m_short_analyzer.Reset();
      }
      string status = "جهت تحلیل: " + EnumToString(m_analysis_direction);
      if(m_active_family != NULL)
         status += " | ساختار فعال: " + EnumToString(m_active_family.GetDirection());
      if(m_panel != NULL)
         m_panel.UpdateStatus(status);
   }

  void HFiboOnNewBar()
{
   // به جای کد قبلی، این کد رو قرار بده
   if(m_analysis_direction == LONG && m_long_analyzer != NULL)
   {
      if(!m_long_analyzer.UpdateOnNewBar())
         m_long_analyzer.Reset();
   }
   else if(m_analysis_direction == SHORT && m_short_analyzer != NULL)
   {
      if(!m_short_analyzer.UpdateOnNewBar())
         m_short_analyzer.Reset();
   }
}
   void HFiboOnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
   {
      if(!InpTestMode || m_test_panel == NULL) return;
      string command = "";
      if(id == CHARTEVENT_OBJECT_CLICK && m_test_panel.OnButtonClick(sparam, command))
      {
         if(command == "StartLong")
         {
            if(!CreateNewStructure(LONG))
               Log("خطا: ایجاد ساختار Long ناموفق بود");
            else if(m_panel != NULL)
               m_panel.UpdateCommand("ساختار Long شروع شد");
         }
         else if(command == "StartShort")
         {
            if(!CreateNewStructure(SHORT))
               Log("خطا: ایجاد ساختار Short ناموفق بود");
            else if(m_panel != NULL)
               m_panel.UpdateCommand("ساختار Short شروع شد");
         }
         else if(command == "Stop")
         {
            StopCurrentStructure();
            if(m_panel != NULL)
               m_panel.UpdateCommand("ساختار متوقف شد");
         }
         SSignal signal = GetSignal();
         if(m_test_panel != NULL)
            m_test_panel.UpdateSignal(signal.type, signal.id);
      }
   }

   void SetAnalysisDirection(ENUM_DIRECTION direction)
   {
      if(m_analysis_direction == direction) return;
      m_analysis_direction = direction;
      Log("جهت تحلیل به " + EnumToString(direction) + " تغییر کرد.");
      if(m_active_family != NULL && m_active_family.GetDirection() != m_analysis_direction)
      {
         StopCurrentStructure();
      }
      if(direction == LONG && m_short_analyzer != NULL)
         m_short_analyzer.Reset();
      if(direction == SHORT && m_long_analyzer != NULL)
         m_long_analyzer.Reset();
   }

   bool CreateNewStructure(ENUM_DIRECTION direction)
   {
      if(m_active_family != NULL)
      {
         Log("خطا: یک ساختار از قبل فعال است.");
         return false;
      }
      if(direction == LONG)
         m_active_family = m_long_analyzer;
      else
         m_active_family = m_short_analyzer;
      if(m_active_family != NULL)
      {
         if(m_active_family.GetState() != SEARCHING)
         {
            m_active_family.SetVisibility(true);
            Log("ساختار پس‌زمینه " + EnumToString(direction) + " فعال و نمایان شد.");
            return true;
         }
         else
         {
            Log("دستور فعال‌سازی دریافت شد، اما ساختار معتبری در پس‌زمینه آماده نیست.");
            m_active_family = NULL;
            return false;
         }
      }
      return false;
   }

   void StopCurrentStructure()
   {
      if(m_active_family != NULL)
      {
         m_active_family.SetVisibility(false);
         Log("ساختار فعال متوقف و دوباره مخفی شد.");
         m_active_family = NULL;
      }
   }

   SSignal GetSignal()
   {
      SSignal signal = {"", ""};
      if(m_active_family != NULL)
         signal = m_active_family.GetSignal();
      return signal;
   }

   double GetMotherZeroPoint()
   {
      if(m_active_family != NULL)
         return m_active_family.GetMotherPrice0();
      return 0.0;
   }

   bool IsStructureBroken()
   {
      if(m_active_family != NULL && m_active_family.GetState() == FAILED)
         return true;
      if(m_active_family == NULL)
         return true;
      return false;
   }

   void AcknowledgeSignal()
   {
      if(m_active_family != NULL)
      {
         m_active_family.Destroy();
         m_active_family = NULL;
         Log("سیگنال تأیید شد، ساختار متوقف شد");
      }
   }
};

//+------------------------------------------------------------------+
//| متغیر سراسری و توابع سراسری                                    |
//+------------------------------------------------------------------+
CStructureManager* g_manager = NULL;

bool HFiboOnInit()
{
   if(g_manager != NULL) return false;
   g_manager = new CStructureManager();
   if(g_manager == NULL) return false;
   if(!g_manager.HFiboOnInit())
   {
      delete g_manager;
      g_manager = NULL;
      return false;
   }
   return true;
}

void HFiboOnDeinit(const int reason)
{
   if(g_manager != NULL)
   {
      g_manager.HFiboOnDeinit(reason);
      delete g_manager;
      g_manager = NULL;
   }
}

void HFiboOnTick()
{
   if(g_manager != NULL)
      g_manager.HFiboOnTick();
}

void HFiboOnNewBar()
{
   if(g_manager != NULL)
      g_manager.HFiboOnNewBar();
}

void HFiboOnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   if(g_manager != NULL)
      g_manager.HFiboOnChartEvent(id, lparam, dparam, sparam);
}

SSignal HFiboGetSignal()
{
   if(g_manager != NULL)
      return g_manager.GetSignal();
   SSignal signal = {"", ""};
   return signal;
}

double HFiboGetMotherZeroPoint()
{
   if(g_manager != NULL)
      return g_manager.GetMotherZeroPoint();
   return 0.0;
}

bool HFiboIsStructureBroken()
{
   if(g_manager != NULL)
      return g_manager.IsStructureBroken();
   return true;
}

void HFiboAcknowledgeSignal()
{
   if(g_manager != NULL)
      g_manager.AcknowledgeSignal();
}

void HFiboSetAnalysisDirection(ENUM_DIRECTION direction)
{
   if(g_manager != NULL)
      g_manager.SetAnalysisDirection(direction);
}
void HFiboStopCurrentStructure()
{
   if(g_manager != NULL)
      g_manager.StopCurrentStructure();
}



