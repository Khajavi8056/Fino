//+------------------------------------------------------------------+
//|                                                  HipoFibonacci.mqh |
//|                              محصولی از: Hipo Algorithm           |
//|                              نسخه: ۱.۶.۱                          |
//|                              تاریخ: ۲۰۲۵/۰۷/۲۳                   |
//| کتابخانه تحلیل فیبوناچی پویا برای متاتریدر ۵ با حالت تست    |
//+------------------------------------------------------------------+

#property copyright "Hipo Algorithm"
#property link      "https://hipoalgorithm.com"
#property version   "1.6.1"

//+------------------------------------------------------------------+
//| تابع عمومی برای بررسی وجود شیء                                  |
//+------------------------------------------------------------------+
bool CheckObjectExists(string name)
{
   for(int i = 0; i < 3; i++)
   {
      if(ObjectFind(0, name) >= 0) return true;
      Sleep(100);
   }
   Print("خطا: عدم رندر شیء " + name);
   return false;
}

//+------------------------------------------------------------------+
//| ورودی‌های کتابخانه                                              |
//+------------------------------------------------------------------+
input group "تنظیمات فراکتال"
input int InpFractalLookback = 200;       // حداکثر تعداد کندل برای جستجوی فراکتال (حداقل 10)
input int InpFractalPeers = 3;            // تعداد کندل‌های چپ/راست برای فراکتال (حداقل 1)

input group "سطوح فیبوناچی"
input string InpMotherLevels = "50,61.8,150,200"; // سطوح فیبو مادر (اعداد مثبت، با کاما)
input string InpChildLevels = "50,61.8";         // سطوح فیبو فرزندان (اعداد مثبت)
input string InpChild2BreakLevels = "150,200";   // سطوح شکست فرزند دوم (اعداد مثبت)
input string InpGoldenZone = "50,61.8";          // ناحیه طلایی برای سیگنال (اعداد مثبت)

input group "فیکس شدن مادر"
enum ENUM_FIX_MODE
{
   PRICE_CROSS,   // عبور لحظه‌ای قیمت
   CANDLE_CLOSE   // کلوز کندل
};
input ENUM_FIX_MODE InpMotherFixMode = PRICE_CROSS; // حالت فیکس شدن مادر

input group "رنگ‌بندی اشیاء"
input color InpMotherColor = clrWhite;    // رنگ فیبوناچی مادر
input color InpChild1Color = clrLime;     // رنگ فیبوناچی فرزند اول
input color InpChild2Color = clrGreen;    // رنگ فیبوناچی فرزند دوم

input group "تنظیمات پنل اصلی"
input bool InpShowPanel = true;           // نمایش پنل اصلی اطلاعاتی
input ENUM_BASE_CORNER InpPanelCorner = CORNER_LEFT_UPPER; // گوشه پنل اصلی
input int InpPanelOffsetX = 10;           // فاصله افقی پنل اصلی (حداقل 0)
input int InpPanelOffsetY = 20;           // فاصله عمودی پنل اصلی (حداقل 0)

input group "تنظیمات حالت تست (هشدار: در این حالت اکسپرت نادیده گرفته می‌شود)"
input bool InpTestMode = true;            // فعال‌سازی حالت تست داخلی
input ENUM_BASE_CORNER InpTestPanelCorner = CORNER_LEFT_UPPER; // گوشه پنل تست (مرکز بالا)
input int InpTestPanelOffsetX = 156;        // فاصله افقی پنل تست از مرکز (حداقل 0)
input int InpTestPanelOffsetY = 40;       // فاصله عمودی پنل تست از بالا (حداقل 0)
input color InpTestPanelButtonColorLong = clrGreen;  // رنگ دکمه Start Long
input color InpTestPanelButtonColorShort = clrRed;   // رنگ دکمه Start Short
input color InpTestPanelButtonColorStop = clrGray;   // رنگ دکمه Stop
input color InpTestPanelBgColor = clrDarkGray;      // رنگ پس‌زمینه پنل تست

input group "تنظیمات دیباگ"
input bool InpVisualDebug = false;        // فعال‌سازی حالت تست بصری

input group "تنظیمات لاگ"
input bool InpEnableLog = true;           // فعال‌سازی لاگ‌گیری
input string InpLogFilePath = "HipoFibonacci_Log.txt"; // مسیر فایل لاگ (MQL5/Files)
input int InpMaxFamilies = 2;             // حداکثر تعداد ساختارهای فعال (حداقل 1)

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

//+------------------------------------------------------------------+
//| کلاس CFractalFinder: پیدا کردن فراکتال‌ها                      |
//+------------------------------------------------------------------+
class CFractalFinder
{
private:
   bool IsHighFractal(int index, int peers)
   {
      for(int i = 1; i <= peers; i++)
      {
         if(iHigh(_Symbol, _Period, index + i) >= iHigh(_Symbol, _Period, index) ||
            iHigh(_Symbol, _Period, index - i) >= iHigh(_Symbol, _Period, index))
            return false;
      }
      return true;
   }

   bool IsLowFractal(int index, int peers)
   {
      for(int i = 1; i <= peers; i++)
      {
         if(iLow(_Symbol, _Period, index + i) <= iLow(_Symbol, _Period, index) ||
            iLow(_Symbol, _Period, index - i) <= iLow(_Symbol, _Period, index))
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
      for(int i = startIndex; i <= MathMin(startIndex + lookback, iBars(_Symbol, _Period) - 1); i++)
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
      for(int i = startIndex; i <= MathMin(startIndex + lookback, iBars(_Symbol, _Period) - 1); i++)
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
      ObjectSetInteger(0, name, OBJPROP_YSIZE, 20);
      ObjectSetInteger(0, name, OBJPROP_BGCOLOR, clrMidnightBlue);
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
             CreateLabel(m_name + "_Title", "Hipo Fibonacci v1.6.1 - 2025/07/23", m_offset_x + 10, m_offset_y + 5, clrWhite, 11, "Calibri Bold") &&
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

public:
   CBaseFibo(string name, color clr, string levels, bool is_test)
   {
      m_name = name;
      m_color = clr;
      m_is_test = is_test;
      string temp_levels[];
      int count = StringSplit(levels, StringGetCharacter(",", 0), temp_levels);
      ArrayResize(m_levels, count);
      for(int i = 0; i < count; i++)
         m_levels[i] = StringToDouble(temp_levels[i]);
   }

   virtual bool Draw()
   {
      string obj_name = m_name + (m_is_test ? "_Test" : "");
      if(!ObjectCreate(0, obj_name, OBJ_FIBO, 0, m_time0, m_price0, m_time100, m_price100))
         return false;
      ObjectSetInteger(0, obj_name, OBJPROP_COLOR, m_color);
      ObjectSetInteger(0, obj_name, OBJPROP_STYLE, STYLE_SOLID);
      for(int i = 0; i < ArraySize(m_levels); i++)
         ObjectSetDouble(0, obj_name, OBJPROP_LEVELVALUE, i, m_levels[i] / 100.0);
      return CheckObjectExists(obj_name);
   }

   void Delete()
   {
      string obj_name = m_name + (m_is_test ? "_Test" : "");
      ObjectDelete(0, obj_name);
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
         Delete();
         if(Draw())
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

   bool CheckStructureFailure(double current_price)
   {
      if(!m_is_fixed) return false; // فقط بعد از فیکس شدن مادر بررسی می‌شود
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

   void Log(string message)
   {
      if(InpEnableLog)
         Print(TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES | TIME_SECONDS) + ": " + message);
   }

public:
   CChildFibo(string name, color clr, string levels, CMotherFibo* mother, bool is_success_child2, bool is_test)
      : CBaseFibo(name, clr, levels, is_test)
   {
      m_is_fixed = false;
      m_is_success_child2 = is_success_child2;
      m_parent_mother = mother;
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
      if(m_parent_mother.GetDirection() == LONG)
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
         Delete();
         if(Draw())
         {
            Log("صد فرزند " + (StringFind(m_name, "Child1") >= 0 ? "اول" : (m_is_success_child2 ? "دوم (موفق)" : "دوم (ناموفق)")) +
                " آپدیت شد: صد=" + DoubleToString(m_price100, _Digits) + ", زمان=" + TimeToString(new_time));
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
            return true;
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
            Log("فرزند دوم (موفق) فعال شد: عبور از صد فرزند اول: قیمت=" + DoubleToString(current_price, _Digits) + ", زمان=" + TimeToString(TimeCurrent()));
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
         Log("فرزند دوم موفق شد (ناحیه طلایی): قیمت=" + DoubleToString(current_price, _Digits) + ", زمان=" + TimeToString(TimeCurrent()));
         if(InpVisualDebug)
         {
            string rect_name = "Debug_Rect_GoldenZone_" + TimeToString(TimeCurrent()) + (m_is_test ? "_Test" : "");
            if(ObjectCreate(0, rect_name, OBJ_RECTANGLE, 0, TimeCurrent(), level_50, TimeCurrent() + PeriodSeconds(), level_618))
            {
               ObjectSetInteger(0, rect_name, OBJPROP_COLOR, clrLightYellow);
               ObjectSetInteger(0, rect_name, OBJPROP_FILL, true);
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
         string temp_levels[];
         int count = StringSplit(InpChild2BreakLevels, StringGetCharacter(",", 0), temp_levels);
         double max_level = StringToDouble(temp_levels[count - 1]); // استفاده از حداکثر سطح
         double break_level = m_parent_mother.GetPrice100() + (m_parent_mother.GetPrice0() - m_parent_mother.GetPrice100()) * max_level / 100.0;
         bool break_condition = (m_parent_mother.GetDirection() == LONG && iClose(_Symbol, _Period, 1) >= break_level) ||
                                (m_parent_mother.GetDirection() == SHORT && iClose(_Symbol, _Period, 1) <= break_level);
         if(break_condition)
         {
            Log("ساختار شکست خورد: کلوز کندل در سطح " + DoubleToString(max_level, 1) + "%: قیمت=" + DoubleToString(iClose(_Symbol, _Period, 1), _Digits) + ", زمان=" + TimeToString(TimeCurrent()));
            if(InpVisualDebug)
            {
               string label_name = "Debug_Label_StructureFail_" + TimeToString(TimeCurrent()) + (m_is_test ? "_Test" : "");
               if(ObjectCreate(0, label_name, OBJ_TEXT, 0, TimeCurrent(), iClose(_Symbol, _Period, 1)))
               {
                  ObjectSetString(0, label_name, OBJPROP_TEXT, "ساختار شکست خورد: کلوز در سطح " + DoubleToString(max_level, 1) + "%");
                  ObjectSetInteger(0, label_name, OBJPROP_COLOR, clrRed);
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
      double min_level = StringToDouble(temp_levels[0]); // استفاده از حداقل سطح
      double break_level = m_parent_mother.GetPrice100() + (m_parent_mother.GetPrice0() - m_parent_mother.GetPrice100()) * min_level / 100.0;
      bool trigger_condition = (m_parent_mother.GetDirection() == LONG && current_price >= break_level) ||
                               (m_parent_mother.GetDirection() == SHORT && current_price <= break_level);
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
         Print(TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES | TIME_SECONDS) + ": " + m_id + ": " + message);
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
      else if(m_state == MOTHER_ACTIVE)
      {
         if(m_mother != NULL && m_mother.CheckStructureFailure(current_price))
         {
            m_state = FAILED;
            Log("ساختار شکست خورد");
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
            Log("ساختار شکست خورد");
            return false;
         }
         if(m_child1 != NULL && m_child1.CheckFailure(current_price))
         {
            m_child1.Delete();
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
            if(m_child1.CheckFixing(current_price) && m_child1.CheckChild1TriggerChild2(current_price))
            {
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
         }
      }
      else if(m_state == CHILD2_ACTIVE)
      {
         if(m_mother != NULL && m_mother.CheckStructureFailure(current_price))
         {
            m_state = FAILED;
            Log("ساختار شکست خورد");
            return false;
         }
         if(m_child2 != NULL && m_child2.CheckFailureChild2OnTick(current_price))
         {
            m_state = FAILED;
            Log("ساختار شکست خورد");
            return false;
         }
         if(m_child2 != NULL && m_child2.UpdateOnTick(current_time))
         {
            if(m_child2.IsSuccessChild2() && m_child2.CheckSuccessChild2(current_price))
            {
               m_state = COMPLETED;
               Log("ساختار کامل شد");
               return true;
            }
            else if(!m_child2.IsSuccessChild2() && m_child2.CheckChild2Trigger(current_price))
            {
               m_child2.Delete();
               m_child2 = new CChildFibo(m_id + "_FailureChild2", InpChild2Color, InpChildLevels, m_mother, false, m_is_test);
               if(m_child2 == NULL || !m_child2.Initialize(current_time))
               {
                  Log("خطا: نمی‌توان فرزند دوم (ناموفق) را ایجاد کرد");
                  delete m_child2;
                  m_child2 = NULL;
                  m_state = FAILED;
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
            Log("سیگنال " + signal.type + ": ID=" + signal.id + ", قیمت=" + DoubleToString(current_price, _Digits));
            if(InpVisualDebug)
            {
               string arrow_name = "Debug_Arrow_Signal_" + TimeToString(TimeCurrent()) + (m_is_test ? "_Test" : "");
               if(ObjectCreate(0, arrow_name, m_direction == LONG ? OBJ_ARROW_UP : OBJ_ARROW_DOWN, 0, TimeCurrent(), current_price))
               {
                  ObjectSetInteger(0, arrow_name, OBJPROP_COLOR, clrGold);
                  CheckObjectExists(arrow_name);
               }
            }
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

   void Log(string message)
   {
      if(InpEnableLog)
      {
         Print(TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES | TIME_SECONDS) + ": " + message);
         int handle = FileOpen(InpLogFilePath, FILE_WRITE | FILE_TXT | FILE_COMMON);
         if(handle != INVALID_HANDLE)
         {
            FileSeek(handle, 0, SEEK_END);
            FileWrite(handle, TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES | TIME_SECONDS) + ": " + message);
            FileClose(handle);
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

   void HFiboOnDeinit(const int reason)
   {
      for(int i = 0; i < ArraySize(m_families); i++)
         if(m_families[i] != NULL) { m_families[i].Destroy(); delete m_families[i]; }
      ArrayResize(m_families, 0);
      if(m_panel != NULL) { m_panel.Destroy(); delete m_panel; m_panel = NULL; }
      if(m_test_panel != NULL) { m_test_panel.Destroy(); delete m_test_panel; m_test_panel = NULL; }
      Log("کتابخانه HipoFibonacci متوقف شد. دلیل: " + IntegerToString(reason));
   }

   void HFiboOnTick()
   {
      double current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      datetime current_time = TimeCurrent();
      for(int i = ArraySize(m_families) - 1; i >= 0; i--)
      {
         if(m_families[i] != NULL && !m_families[i].UpdateOnTick(current_price, current_time))
         {
            m_families[i].Destroy();
            delete m_families[i];
            m_families[i] = NULL;
         }
      }
      string status = "ساختارهای فعال: " + IntegerToString(ArraySize(m_families));
      if(m_panel != NULL)
         m_panel.UpdateStatus(status);
   }

   void HFiboOnNewBar()
   {
      for(int i = ArraySize(m_families) - 1; i >= 0; i--)
      {
         if(m_families[i] != NULL && !m_families[i].UpdateOnNewBar())
         {
            m_families[i].Destroy();
            delete m_families[i];
            m_families[i] = NULL;
         }
      }
      Log("رویداد کندل جدید دریافت شد");
   }

   bool CreateNewStructure(ENUM_DIRECTION direction)
   {
      if(ArraySize(m_families) >= InpMaxFamilies)
      {
         Log("خطا: تعداد ساختارها به حداکثر رسیده است");
         return false;
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
            if(command == "StartLong")
               CreateNewStructure(LONG);
            else if(command == "StartShort")
               CreateNewStructure(SHORT);
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
               m_is_test_mode = false;
            }
            else
            {
               Log("حالت تست فعال شد");
               if(m_panel != NULL)
                  m_panel.UpdateTestStatus("فعال");
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
         for(int i = ArraySize(m_families) - 1; i >= 0; i--)
         {
            if(m_families[i] != NULL)
            {
               m_families[i].Destroy();
               delete m_families[i];
               m_families[i] = NULL;
            }
         }
         Log("حالت تست غیرفعال شد");
         if(m_panel != NULL)
            m_panel.UpdateTestStatus("غیرفعال");
      }
   }
};

//+------------------------------------------------------------------+
//| توابع عمومی کتابخانه با پیشوند HFibo                          |
//+------------------------------------------------------------------+
CStructureManager* g_manager = NULL;

bool HFiboStartStructure(ENUM_DIRECTION direction)
{
   if(g_manager != NULL) return g_manager.CreateNewStructure(direction);
   return false;
}

SSignal HFiboGetSignal()
{
   if(g_manager != NULL) return g_manager.GetSignal();
   SSignal signal = {"", ""};
   return signal;
}

bool HFiboAcknowledgeSignal(string id)
{
   if(g_manager != NULL) return g_manager.AcknowledgeSignal(id);
   return false;
}

//+------------------------------------------------------------------+
