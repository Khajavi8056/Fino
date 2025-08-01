//+------------------------------------------------------------------+
//|                                                  HipoFibonacci.mqh |
//|                              محصولی از: Hipo Algorithm           |
//|                              نسخه: ۱.۶.۷                          |
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
input string InpChild2BreakLevels = "";              // سطوح شکست فرزند دوم (اختیاری، اعداد مثبت، با کاما)
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
input color InpChild1Color = clrMagenta;  // رنگ فیبوناچی فرزند اول
input color InpChild2Color = clrGreen;    // رنگ فیبوناچی فرزند دوم

input bool InpShowPanelEa = true;           // نمایش پنل اصلی اطلاعاتی
input ENUM_BASE_CORNER InpPanelCorner = CORNER_LEFT_UPPER; // گوشه پنل اصلی
input int InpPanelOffsetX = 10;           // فاصله افقی پنل اصلی (حداقل 0)
input int InpPanelOffsetY = 136;          // فاصله عمودی پنل اصلی (حداقل 0)

input bool InpTestMode = false;            // فعال‌سازی حالت تست داخلی
input ENUM_BASE_CORNER InpTestPanelCorner = CORNER_RIGHT_UPPER; // گوشه پنل تست
input int InpTestPanelOffsetX = 153;      // فاصله افقی پنل تست
input int InpTestPanelOffsetY = 39;       // فاصله عمودی پنل تست
input color InpTestPanelButtonColorLong = clrGreen;  // رنگ دکمه Start Long
input color InpTestPanelButtonColorShort = clrRed;   // رنگ دکمه Start Short
input color InpTestPanelButtonColorStop = clrGray;   // رنگ دکمه Stop
input color InpTestPanelBgColor = clrDarkGray;      // رنگ پس‌زمینه پنل تست

input bool InpVisualDebug = false;        // فعال‌سازی حالت تست بصری

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
   LONG,  // خرید
   SHORT  // فروش
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
   bool IsHighFractal(int index, int peers)
   {
      if(index + peers >= iBars(_Symbol, _Period)) return false;
      if(index - peers < 0) return false;
      double high = iHigh(_Symbol, _Period, index);
      for(int i = 1; i <= peers; i++)
      {
         if(iHigh(_Symbol, _Period, index + i) >= high ||
            iHigh(_Symbol, _Period, index - i) >= high)
            return false;
      }
      return true;
   }

   bool IsLowFractal(int index, int peers)
   {
      if(index + peers >= iBars(_Symbol, _Period)) return false;
      if(index - peers < 0) return false;
      double low = iLow(_Symbol, _Period, index);
      for(int i = 1; i <= peers; i++)
      {
         if(iLow(_Symbol, _Period, index + i) <= low ||
            iLow(_Symbol, _Period, index - i) <= low)
            return false;
      }
      return true;
   }

public:
   void FindRecentHigh(datetime startTime, int lookback, int peers, SFractal &fractal)
   {
      fractal.price = 0.0;
      fractal.time = 0;
      int startIndex = iBarShift(_Symbol, _Period, startTime);
      for(int i = startIndex; i <= MathMin(startIndex + lookback, iBars(_Symbol, _Period) - peers - 1); i++)
      {
         if(IsHighFractal(i, peers))
         {
            fractal.price = iHigh(_Symbol, _Period, i);
            fractal.time = iTime(_Symbol, _Period, i);
            break;
         }
      }
   }

   void FindRecentLow(datetime startTime, int lookback, int peers, SFractal &fractal)
   {
      fractal.price = 0.0;
      fractal.time = 0;
      int startIndex = iBarShift(_Symbol, _Period, startTime);
      for(int i = startIndex; i <= MathMin(startIndex + lookback, iBars(_Symbol, _Period) - peers - 1); i++)
      {
         if(IsLowFractal(i, peers))
         {
            fractal.price = iLow(_Symbol, _Period, i);
            fractal.time = iTime(_Symbol, _Period, i);
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
   bool m_is_visible; // متغیر جدید برای کنترل نمایش

public:
   CBaseFibo(string name, color clr, string levels, bool is_test)
   {
      m_name = name;
      m_color = clr;
      m_is_test = is_test;
      m_is_visible = true; // به طور پیش‌فرض قابل مشاهده
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

   void SetVisible(bool visible)
   {
      if(m_is_visible == visible) return;
      m_is_visible = visible;
      if(m_is_visible)
         Draw();
      else
         Delete();
   }

   virtual bool Draw()
   {
      if(!m_is_visible)
      {
         Delete();
         return true;
      }
      string obj_name = m_name + (m_is_test ? "_Test" : "");
      ObjectDelete(0, obj_name);
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
   double m_breakout_failure_price;

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
      if(!m_is_visible)
      {
         Delete();
         return true;
      }
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

         double target_level = 250.0;
         bool level_found = false;
         for(int i = 0; i < ArraySize(m_levels); i++)
         {
            if(MathAbs(m_levels[i] - target_level) < 0.01)
            {
               level_found = true;
               if(m_direction == LONG)
                  m_breakout_failure_price = m_price100 + (m_price100 - m_price0) * (target_level / 100.0);
               else
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

         double target_level = 250.0;
         bool level_found = false;
         for(int i = 0; i < ArraySize(m_levels); i++)
         {
            if(MathAbs(m_levels[i] - target_level) < 0.01)
            {
               level_found = true;
               if(m_direction == LONG)
                  m_breakout_failure_price = m_price100 + (m_price100 - m_price0) * (target_level / 100.0);
               else
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
   ENUM_DIRECTION m_direction;
   bool m_breakout_triggered;
   datetime m_breakout_candle_time;
   double m_breakout_candle_high;
   double m_breakout_candle_low;
   int m_breakout_candle_count;
   datetime m_fixation_time;
   double m_fixation_price;
   datetime m_breakout_time;
   double m_breakout_price;

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
      m_direction = mother != NULL ? mother.GetDirection() : LONG;
      m_breakout_triggered = false;
      m_breakout_candle_time = 0;
      m_breakout_candle_high = 0.0;
      m_breakout_candle_low = 0.0;
      m_breakout_candle_count = 0;
   }

   virtual bool Draw() override
   {
      if(!m_is_visible)
      {
         Delete();
         return true;
      }
      string obj_name = m_name + (m_is_test ? "_Test" : "");
      ObjectDelete(0, obj_name);
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

   bool CheckSuccessChild2(double current_price)
   {
      if(m_parent_mother == NULL) return false;
      string temp_levels[];
      int count = StringSplit(InpGoldenZone, StringGetCharacter(",", 0), temp_levels);
      if(count < 2)
      {
         Log("خطا: ناحیه طلایی نامعتبر است: " + InpGoldenZone);
         return false;
      }
      double level_1 = StringToDouble(temp_levels[0]) / 100.0;
      double level_2 = StringToDouble(temp_levels[1]) / 100.0;
      if(level_1 >= level_2)
      {
         Log("خطا: ناحیه طلایی نامعتبر است، حداقل باید کوچکتر از حداکثر باشد: " + InpGoldenZone);
         return false;
      }
      double price_level_1 = m_price100 + (m_price0 - m_price100) * level_1;
      double price_level_2 = m_price100 + (m_price0 - m_price100) * level_2;
      double zone_lower_bound = MathMin(price_level_1, price_level_2);
      double zone_upper_bound = MathMax(price_level_1, price_level_2);
      bool success_condition = (current_price >= zone_lower_bound && current_price <= zone_upper_bound);
      if(success_condition)
      {
         Log("فرزند دوم وارد ناحیه طلایی شد: قیمت=" + DoubleToString(current_price, _Digits) + ", زمان=" + TimeToString(TimeCurrent()));
         if(InpVisualDebug)
         {
            string rect_name = "Debug_Rect_GoldenZone_" + TimeToString(TimeCurrent()) + (m_is_test ? "_Test" : "");
            if(ObjectCreate(0, rect_name, OBJ_RECTANGLE, 0, TimeCurrent(), zone_lower_bound, TimeCurrent() + PeriodSeconds(), zone_upper_bound))
            {
               ObjectSetInteger(0, rect_name, OBJPROP_COLOR, clrGoldenrod);
               ObjectSetInteger(0, rect_name, OBJPROP_BGCOLOR, clrGoldenrod);
               ObjectSetInteger(0, rect_name, OBJPROP_FILL, true);
               ObjectSetInteger(0, rect_name, OBJPROP_ZORDER, -1);
               CheckObjectExists(rect_name);
            }
            string arrow_name = "Debug_Arrow_Signal_" + TimeToString(TimeCurrent()) + (m_is_test ? "_Test" : "");
            if(ObjectCreate(0, arrow_name, m_parent_mother.GetDirection() == LONG ? OBJ_ARROW_UP : OBJ_ARROW_DOWN, 0, TimeCurrent(), current_price))
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
            if(MathAbs(m_parent_mother.GetLevel(i) - target_level) < 0.01)
            {
               level_found = true;
               double break_level;
               if(m_parent_mother.GetDirection() == LONG)
                  break_level = m_parent_mother.GetPrice100() + (m_parent_mother.GetPrice100() - m_parent_mother.GetPrice0()) * (target_level / 100.0);
               else
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
      m_mother = new CMotherFibo(m_id + "_Mother", InpMotherColor, InpMotherLevels, m_direction, m_is_test);
      if(m_mother == NULL)
      {
         Log("خطا: نمی‌توان مادر را ایجاد کرد");
         return false;
      }
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
         if(TryUpdateMotherFractal())
         {
            return true;
         }
         if(m_mother != NULL && m_mother.CheckStructureFailure(current_price))
         {
            m_state = FAILED;
            Log("ساختار شکست خورد: لنگرگاه مادر سوراخ شد");
            return false;
         }
         if(m_mother != NULL && !m_mother.UpdateOnTick(current_time)) return false;
         if(m_mother != NULL && InpMotherFixMode == PRICE_CROSS && m_mother.CheckFixingPriceCross(current_price))
         {
            m_child1 = new CChildFibo(m_id + "_Child1", InpChild1Color, InpChildLevels, m_mother, false, m_is_test);
            if(m_child1 == NULL || !m_child1.Initialize(current_time))
            {
               Log("خطا: نمی‌توان فرزند اول را ایجاد کرد");
               delete m_child1;
               m_child1 = NULL;
               m_state = FAILED;
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
            if(m_child2 == NULL || !m_child2.Initialize(current_time))
            {
               Log("خطا: نمی‌توان فرزند دوم (ناموفق) را ایجاد کرد");
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
               m_child1.Delete();
               delete m_child1;
               m_child1 = NULL;
               m_child2 = new CChildFibo(m_id + "_SuccessChild2", InpChild2Color, InpChildLevels, m_mother, true, m_is_test);
               if(m_child2 == NULL || !m_child2.Initialize(current_time))
               {
                  Log("خطا: نمی‌توان فرزند دوم (موفق) را ایجاد کرد");
                  delete m_child2;
                  m_child2 = NULL;
                  m_state = FAILED;
                  return false;
               }
               m_state = CHILD2_ACTIVE;
               Log("فرزند اول فیکس شد و قیمت از صد آن عبور کرد، ساختار به فرزند دوم (موفق) تغییر کرد");
            }
            else
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
         if(m_child2 != NULL && m_child2.UpdateOnTick(current_time))
         {
            if(m_child2.CheckSuccessChild2(current_price))
            {
               Log("فرزند دوم وارد ناحیه طلایی شد: قیمت=" + DoubleToString(current_price, _Digits) + ", زمان=" + TimeToString(current_time) + " (سیگنال آماده)");
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
            m_child1 = new CChildFibo(m_id + "_Child1", InpChild1Color, InpChildLevels, m_mother, false, m_is_test);
            if(m_child1 == NULL || !m_child1.Initialize(TimeCurrent()))
            {
               Log("خطا: نمی‌توان فرزند اول را ایجاد کرد");
               delete m_child1;
               m_child1 = NULL;
               m_state = FAILED;
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
            m_state = FAILED;
            Log("ساختار شکست خورد");
            return false;
         }
      }
      return true;
   }

   SFibonacciEventData GetLastEventData()
   {
      if(m_child2 != NULL)
      {
         return m_child2.GetEventData();
      }
      if(m_child1 != NULL)
      {
         return m_child1.GetEventData();
      }
      SFibonacciEventData empty_data;
      return empty_data;
   }

   bool TryUpdateMotherFractal()
   {
      if(m_mother == NULL || m_mother.IsFixed())
         return false;

      datetime current_mother_time = m_mother.GetTime100();
      SFractal new_fractal;
      if(m_direction == LONG)
         m_fractal_finder.FindRecentHigh(TimeCurrent(), InpFractalLookback, InpFractalPeers, new_fractal);
      else
         m_fractal_finder.FindRecentLow(TimeCurrent(), InpFractalLookback, InpFractalPeers, new_fractal);

      if(new_fractal.price != 0.0 && new_fractal.time > current_mother_time)
      {
         Log("نگهبان مادر: فراکتال بی‌اعتبار در " + TimeToString(current_mother_time) + " شناسایی شد.");
         Log("--> فراکتال جدید در " + TimeToString(new_fractal.time) + " یافت شد. در حال ریست کردن مادر...");

         m_mother.Delete();
         delete m_mother;
         m_mother = NULL;

         if(InpVisualDebug)
            ClearDebugObjects(m_is_test);

         m_mother = new CMotherFibo(m_id + "_Mother", InpMotherColor, InpMotherLevels, m_direction, m_is_test);
         if(m_mother == NULL)
         {
            Log("خطای حیاتی: ایجاد مادر جدید پس از ریست ناموفق بود.");
            m_state = FAILED;
            return false;
         }

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

   SSignal GetSignal()
   {
      SSignal signal = {"", ""};
      if(m_state == CHILD2_ACTIVE && m_child2 != NULL)
      {
         string temp_levels[];
         int count = StringSplit(InpGoldenZone, StringGetCharacter(",", 0), temp_levels);
         if(count < 2)
         {
            Log("خطا: ناحیه طلایی نامعتبر است: " + InpGoldenZone);
            return signal;
         }
         double level_1 = StringToDouble(temp_levels[0]) / 100.0;
         double level_2 = StringToDouble(temp_levels[1]) / 100.0;
         if(level_1 >= level_2)
         {
            Log("خطا: ناحیه طلایی نامعتبر است، حداقل باید کوچکتر از حداکثر باشد: " + InpGoldenZone);
            return signal;
         }
         double price_level_1 = m_child2.GetPrice100() + (m_child2.GetPrice0() - m_child2.GetPrice100()) * level_1;
         double price_level_2 = m_child2.GetPrice100() + (m_child2.GetPrice0() - m_child2.GetPrice100()) * level_2;
         double zone_lower_bound = MathMin(price_level_1, price_level_2);
         double zone_upper_bound = MathMax(price_level_1, price_level_2);
         double current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         bool in_golden_zone = (current_price >= zone_lower_bound && current_price <= zone_upper_bound);
         if(in_golden_zone)
         {
            signal.type = m_direction == LONG ? "Buy" : "Sell";
            signal.id = m_id + "_" + TimeToString(TimeCurrent()) + "_" + (m_direction == LONG ? "Long" : "Short") + "_" + (m_child2.IsSuccessChild2() ? "Success" : "Failure");
            Log("سیگنال " + signal.type + " صادر شد: ID=" + signal.id + ", قیمت=" + DoubleToString(current_price, _Digits));
            m_state = COMPLETED;
            Log("ساختار با ورود به ناحیه طلایی کامل شد و سیگنال صادر گردید.");
         }
      }
      return signal;
   }

   bool IsActive()
   {
      return m_state != COMPLETED && m_state != FAILED;
   }

   void Destroy()
   {
      if(m_child2 != NULL) { m_child2.Delete(); delete m_child2; m_child2 = NULL; }
      if(m_child1 != NULL) { m_child1.Delete(); delete m_child1; m_child1 = NULL; }
      if(m_mother != NULL) { m_mother.Delete(); delete m_mother; m_mother = NULL; }
      m_state = FAILED;
      if(InpVisualDebug)
         ClearDebugObjects(m_is_test);
   }

   void ApplyVisibility(bool visible)
   {
      if(m_mother != NULL) m_mother.SetVisible(visible);
      if(m_child1 != NULL) m_child1.SetVisible(visible);
      if(m_child2 != NULL) m_child2.SetVisible(visible);
      if(!visible && InpVisualDebug)
         ClearDebugObjects(m_is_test);
   }

   double GetMotherPrice0()
   {
      if(m_mother != NULL)
         return m_mother.GetPrice0();
      return 0.0;
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
   string m_log_buffer;

   void Log(string message)
   {
      if(InpEnableLog)
      {
         string log_entry = TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES | TIME_SECONDS) + ": " + message + "\n";
         m_log_buffer += log_entry;
         Print(log_entry);
      }
   }

   void CompactFamiliesArray()
   {
      CFamily* temp_families[];
      int new_size = 0;
      for(int i = 0; i < ArraySize(m_families); i++)
      {
         if(m_families[i] != NULL)
         {
            ArrayResize(temp_families, new_size + 1);
            temp_families[new_size] = m_families[i];
            new_size++;
         }
      }
      ArrayFree(m_families);
      if(new_size > 0)
         ArrayCopy(m_families, temp_families, 0, 0, WHOLE_ARRAY);
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
      }
   }

public:
   CStructureManager()
   {
      ArrayResize(m_families, 0);
      m_panel = NULL;
      m_test_panel = NULL;
      m_is_test_mode = false;
      m_current_command = "";
      m_log_buffer = "";
   }

   static void AddLog(string message)
   {
      if(g_manager != NULL)
         g_manager.Log(message);
   }

   bool HFiboOnInit()
   {
      ChartSetInteger(0, CHART_EVENT_OBJECT_CREATE, true);
      ChartSetInteger(0, CHART_EVENT_MOUSE_MOVE, true);
      if(InpShowPanelEa)
      {
         m_panel = new CPanel("HipoFibo_Panel", InpPanelCorner, InpPanelOffsetX, InpPanelOffsetY);
         if(m_panel == NULL || !m_panel.Create())
         {
            Log("خطا: نمی‌توان پنل اصلی را ایجاد کرد");
            return false;
         }
      }
      if(InpTestMode)
      {
         EnableTestMode(true);
      }
      Log("کتابخانه HipoFibonacci راه‌اندازی شد");
      return true;
   }

   SFibonacciEventData GetActiveFamilyEventData()
   {
      if(ArraySize(m_families) > 0 && m_families[0] != NULL)
      {
         return m_families[0].GetLastEventData();
      }
      SFibonacciEventData empty_data;
      return empty_data;
   }

   void HFiboOnDeinit(const int reason)
   {
      for(int i = 0; i < ArraySize(m_families); i++)
         if(m_families[i] != NULL) { m_families[i].Destroy(); delete m_families[i]; }
      ArrayResize(m_families, 0);
      if(m_panel != NULL) { m_panel.Destroy(); delete m_panel; m_panel = NULL; }
      if(m_test_panel != NULL) { m_test_panel.Destroy(); delete m_test_panel; m_test_panel = NULL; }
      if(InpVisualDebug)
         ClearDebugObjects(m_is_test_mode);
      FlushLog();
      Log("کتابخانه HipoFibonacci متوقف شد. دلیل: " + IntegerToString(reason));
   }

   void HFiboOnTick()
   {
      double current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      datetime current_time = TimeCurrent();
      bool needs_compacting = false;

      for(int i = ArraySize(m_families) - 1; i >= 0; i--)
      {
         if(m_families[i] != NULL && !m_families[i].UpdateOnTick(current_price, current_time))
         {
            m_families[i].Destroy();
            delete m_families[i];
            m_families[i] = NULL;
            needs_compacting = true;
         }
      }

      if(needs_compacting)
      {
         CompactFamiliesArray();
      }

      string status = "ساختارهای فعال: " + IntegerToString(ArraySize(m_families));
      if(m_panel != NULL)
         m_panel.UpdateStatus(status);
   }

   void HFiboOnNewBar()
   {
      bool needs_compacting = false;

      for(int i = ArraySize(m_families) - 1; i >= 0; i--)
      {
         if(m_families[i] != NULL && !m_families[i].UpdateOnNewBar())
         {
            m_families[i].Destroy();
            delete m_families[i];
            m_families[i] = NULL;
            needs_compacting = true;
         }
      }

      if(needs_compacting)
      {
         CompactFamiliesArray();
      }

      FlushLog();
   }

   bool CreateNewStructure(ENUM_DIRECTION direction)
   {
      if(ArraySize(m_families) >= InpMaxFamilies)
      {
         for(int i = 0; i < ArraySize(m_families); i++)
         {
            if(m_families[i] != NULL && m_families[i].IsActive())
            {
               Log("خطا: یک ساختار فعال وجود دارد. لطفاً ابتدا آن را متوقف کنید.");
               return false;
            }
         }
         for(int i = ArraySize(m_families) - 1; i >= 0; i--)
         {
            if(m_families[i] != NULL && !m_families[i].IsActive())
            {
               m_families[i].Destroy();
               delete m_families[i];
               m_families[i] = NULL;
            }
         }
         ArrayResize(m_families, 0);
      }
      CFamily* family = new CFamily("Family_" + TimeToString(TimeCurrent()), direction, m_is_test_mode);
      if(family == NULL || !family.Initialize())
      {
         Log("خطا: نمی‌توان ساختار جدید را ایجاد کرد");
         delete family;
         return false;
      }
      int index = ArraySize(m_families);
      ArrayResize(m_families, index + 1);
      m_families[index] = family;
      Log("ساختار جدید ایجاد شد: جهت=" + (direction == LONG ? "Long" : "Short"));
      return true;
   }

   SSignal GetSignal()
   {
      SSignal signal = {"", ""};
      for(int i = 0; i < ArraySize(m_families); i++)
      {
         if(m_families[i] != NULL)
         {
            SSignal temp_signal = m_families[i].GetSignal();
            if(temp_signal.id != "")
            {
               signal = temp_signal;
               if(m_test_panel != NULL)
                  m_test_panel.UpdateSignal(signal.type, signal.id);
               break;
            }
         }
      }
      return signal;
   }

   bool AcknowledgeSignal(string id)
   {
      for(int i = 0; i < ArraySize(m_families); i++)
      {
         if(m_families[i] != NULL && m_families[i].GetState() == COMPLETED)
         {
            m_families[i].Destroy();
            delete m_families[i];
            m_families[i] = NULL;
            Log("سیگنال تأیید شد: ID=" + id);
            return true;
         }
      }
      return false;
   }

   void HFiboOnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
   {
      if(id == CHARTEVENT_OBJECT_CLICK && m_test_panel != NULL)
      {
         string command;
         if(m_test_panel.OnButtonClick(sparam, command))
         {
            m_current_command = command;
            if(m_panel != NULL)
               m_panel.UpdateTestStatus(command);
            if(command == "StartLong" || command == "StartShort")
            {
               ENUM_DIRECTION direction = (command == "StartLong") ? LONG : SHORT;
               CreateNewStructure(direction);
            }
            else if(command == "Stop")
            {
               for(int i = ArraySize(m_families) - 1; i >= 0; i--)
               {
                  if(m_families[i] != NULL)
                  {
                     m_families[i].Destroy();
                     delete m_families[i];
                     m_families[i] = NULL;
                  }
               }
               Log("حالت تست: دستور توقف دریافت شد");
            }
         }
      }
   }

   void EnableTestMode(bool enable)
   {
      m_is_test_mode = enable;
      if(enable)
      {
         if(m_test_panel == NULL)
         {
            m_test_panel = new CTestPanel("HipoFibo_TestPanel", InpTestPanelCorner, InpTestPanelOffsetX, InpTestPanelOffsetY,
                                          InpTestPanelButtonColorLong, InpTestPanelButtonColorShort, InpTestPanelButtonColorStop, InpTestPanelBgColor);
            if(m_test_panel == NULL || !m_test_panel.Create())
            {
               Log("خطا: نمی‌توان پنل تست را ایجاد کرد");
               delete m_test_panel;
               m_test_panel = NULL;
            }
         }
      }
      else
      {
         if(m_test_panel != NULL)
         {
            m_test_panel.Destroy();
            delete m_test_panel;
            m_test_panel = NULL;
         }
      }
   }

   double GetMotherZeroPoint()
   {
      if(ArraySize(m_families) > 0 && m_families[0] != NULL)
      {
         return m_families[0].GetMotherPrice0();
      }
      return 0.0;
   }

   void StopCurrentStructure()
   {
      for(int i = ArraySize(m_families) - 1; i >= 0; i--)
      {
         if(m_families[i] != NULL)
         {
            m_families[i].Destroy();
            delete m_families[i];
            m_families[i] = NULL;
            Log("دستور توقف از اکسپرت دریافت و ساختار فعال متوقف شد.");
         }
      }
      ArrayResize(m_families, 0);
   }

   void SetVisibility(bool visible)
   {
      for(int i = 0; i < ArraySize(m_families); i++)
      {
         if(m_families[i] != NULL)
            m_families[i].ApplyVisibility(visible);
      }
   }

   int GetActiveFamiliesCount()
   {
      return ArraySize(m_families);
   }
};

//+------------------------------------------------------------------+
//| متغیرهای سراسری                                                |
//+------------------------------------------------------------------+
CStructureManager* g_manager = NULL;

//+------------------------------------------------------------------+
//| توابع سراسری برای استفاده در اکسپرت                           |
//+------------------------------------------------------------------+
bool HFiboOnInit()
{
   g_manager = new CStructureManager();
   if(g_manager == NULL)
   {
      Print("خطا: نمی‌توان CStructureManager را ایجاد کرد");
      return false;
   }
   return g_manager.HFiboOnInit();
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

SSignal HFiboGetSignal()
{
   if(g_manager != NULL)
      return g_manager.GetSignal();
   SSignal signal = {"", ""};
   return signal;
}

bool HFiboAcknowledgeSignal(string id)
{
   if(g_manager != NULL)
      return g_manager.AcknowledgeSignal(id);
   return false;
}

void HFiboOnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   if(g_manager != NULL)
      g_manager.HFiboOnChartEvent(id, lparam, dparam, sparam);
}

bool HFiboCreateNewStructure(ENUM_DIRECTION direction)
{
   if(g_manager != NULL)
      return g_manager.CreateNewStructure(direction);
   return false;
}

double HFiboGetMotherZeroPoint()
{
   if(g_manager != NULL)
      return g_manager.GetMotherZeroPoint();
   return 0.0;
}

void HFiboStopCurrentStructure()
{
   if(g_manager != NULL)
      g_manager.StopCurrentStructure();
}

bool HFiboIsStructureBroken()
{
   if(g_manager != NULL && g_manager.GetActiveFamiliesCount() == 0)
   {
      return true;
   }
   return false;
}

SFibonacciEventData HFiboGetLastEventData()
{
   if(g_manager != NULL)
   {
      return g_manager.GetActiveFamilyEventData();
   }
   SFibonacciEventData empty_data;
   return empty_data;
}

void HFiboSetVisibility(bool visible)
{
   if(g_manager != NULL)
      g_manager.SetVisibility(visible);
}
