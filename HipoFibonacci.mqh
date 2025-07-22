//+------------------------------------------------------------------+
//|                                                  HipoFibonacci.mqh |
//|                              محصولی از: Hipo Algorithm           |
//|                              نسخه: ۱.۲                            |
//|                              تاریخ: ۲۰۲۵/۰۷/۲۲                   |
//| کتابخانه تحلیل فیبوناچی پویا برای متاتریدر ۵ با حالت تست    |
//+------------------------------------------------------------------+

#property copyright "Hipo Algorithm"
#property link      "https://hipoalgorithm.com"
#property version   "1.2" //beta

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
input bool InpTestMode = false;           // فعال‌سازی حالت تست داخلی
input ENUM_BASE_CORNER InpTestPanelCorner = CORNER_RIGHT_UPPER; // گوشه پنل تست (مرکز بالا)
input int InpTestPanelOffsetX = 0;        // فاصله افقی پنل تست از مرکز
input int InpTestPanelOffsetY = 20;       // فاصله عمودی پنل تست از بالا
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

   bool CreateLabel(string name, string text, int x, int y, color clr)
   {
      if(!ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0))
         return false;
      ObjectSetInteger(0, name, OBJPROP_CORNER, m_corner);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
      ObjectSetString(0, name, OBJPROP_TEXT, text);
      ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 10);
      return true;
   }

public:
   CPanel(string name, ENUM_BASE_CORNER corner, int x, int y)
   {
      m_name = name;
      m_corner = corner;
      m_offset_x = x;
      m_offset_y = y;
   }

   bool Create()
   {
      return CreateLabel(m_name + "_Status", "Hipo Fibonacci: در حال انتظار", m_offset_x, m_offset_y, clrWhite) &&
             CreateLabel(m_name + "_Command", "دستور: هیچ", m_offset_x, m_offset_y + 20, clrWhite);
   }

   void UpdateStatus(string status)
   {
      ObjectSetString(0, m_name + "_Status", OBJPROP_TEXT, status);
   }

   void UpdateCommand(string command)
   {
      ObjectSetString(0, m_name + "_Command", OBJPROP_TEXT, "دستور: " + command);
   }

   void UpdateTestStatus(string status)
   {
      ObjectSetString(0, m_name + "_Status", OBJPROP_TEXT, "حالت تست: " + status);
   }

   void Destroy()
   {
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
         return false;
      ObjectSetInteger(0, name, OBJPROP_CORNER, m_corner);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
      ObjectSetInteger(0, name, OBJPROP_XSIZE, 100);
      ObjectSetInteger(0, name, OBJPROP_YSIZE, 30);
      ObjectSetString(0, name, OBJPROP_TEXT, text);
      ObjectSetInteger(0, name, OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, name, OBJPROP_BGCOLOR, clr);
      return true;
   }

   bool CreateBackground(string name, int x, int y)
   {
      if(!ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0))
         return false;
      ObjectSetInteger(0, name, OBJPROP_CORNER, m_corner);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
      ObjectSetInteger(0, name, OBJPROP_XSIZE, 320);
      ObjectSetInteger(0, name, OBJPROP_YSIZE, 40);
      ObjectSetInteger(0, name, OBJPROP_BGCOLOR, m_bg_color);
      return true;
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
      return CreateBackground(m_name + "_Bg", m_offset_x, m_offset_y) &&
             CreateButton(m_name + "_StartLong", "Start Long", m_offset_x + 10, m_offset_y + 5, m_button_color_long) &&
             CreateButton(m_name + "_StartShort", "Start Short", m_offset_x + 110, m_offset_y + 5, m_button_color_short) &&
             CreateButton(m_name + "_Stop", "Stop", m_offset_x + 210, m_offset_y + 5, m_button_color_stop);
   }

   bool OnButtonClick(string button, string &command)
   {
      if(ObjectGetInteger(0, button, OBJPROP_STATE))
      {
         ObjectSetInteger(0, button, OBJPROP_STATE, false);
         if(StringFind(button, "_StartLong") >= 0) { command = "StartLong"; return true; }
         if(StringFind(button, "_StartShort") >= 0) { command = "StartShort"; return true; }
         if(StringFind(button, "_Stop") >= 0) { command = "Stop"; return true; }
      }
      return false;
   }

   void Destroy()
   {
      ObjectDelete(0, m_name + "_Bg");
      ObjectDelete(0, m_name + "_StartLong");
      ObjectDelete(0, m_name + "_StartShort");
      ObjectDelete(0, m_name + "_Stop");
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

   bool CheckObjectExists(string name)
   {
      for(int i = 0; i < 3; i++)
      {
         if(ObjectFind(0, name) >= 0) return true;
         Sleep(100);
      }
      Log("خطا: عدم رندر شیء " + name);
      return false;
   }

   void Log(string message)
   {
      if(InpEnableLog)
         CStructureManager::LogStatic(message);
   }

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

   bool Update(datetime new_time)
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

   bool CheckFixing(double current_price)
   {
      if(m_is_fixed) return true;
      double level_50 = m_price100 + (m_price0 - m_price100) * 0.5;
      bool fix_condition = (m_direction == LONG && current_price >= level_50) ||
                           (m_direction == SHORT && current_price <= level_50);
      if(fix_condition)
      {
         m_is_fixed = true;
         Log("مادر فیکس شد: صفر=" + DoubleToString(m_price0, _Digits) + ", زمان=" + TimeToString(TimeCurrent()));
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

   bool CheckFixingOnBar()
   {
      if(m_is_fixed) return true;
      double level_50 = m_price100 + (m_price0 - m_price100) * 0.5;
      bool fix_condition = (m_direction == LONG && iClose(_Symbol, _Period, 1) >= level_50) ||
                           (m_direction == SHORT && iClose(_Symbol, _Period, 1) <= level_50);
      if(fix_condition)
      {
         m_is_fixed = true;
         Log("مادر فیکس شد (OnBar): صفر=" + DoubleToString(m_price0, _Digits) + ", زمان=" + TimeToString(TimeCurrent()));
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
      m_time0 = m_parent_mother->GetTime0();
      m_price0 = m_parent_mother->GetPrice0();
      if(m_parent_mother->GetDirection() == LONG)
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
            if(ObjectCreate(0, arrow_name, m_parent_mother->GetDirection() == LONG ? OBJ_ARROW_UP : OBJ_ARROW_DOWN, 0, m_time100, m_price100))
            {
               ObjectSetInteger(0, arrow_name, OBJPROP_COLOR, StringFind(m_name, "Child1") >= 0 ? (m_parent_mother->GetDirection() == LONG ? clrCyan : clrPink) :
                                                               (m_parent_mother->GetDirection() == LONG ? clrDarkGreen : clrDarkRed));
               CheckObjectExists(arrow_name);
            }
         }
         return true;
      }
      return false;
   }

   bool Update(datetime new_time)
   {
      if(m_is_fixed) return true;
      double old_price100 = m_price100;
      if(m_parent_mother->GetDirection() == LONG)
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
      if(m_is_fixed || StringFind(m_name, "Child2") >= 0) return false;
      double level_50 = m_price100 + (m_price0 - m_price100) * 0.5;
      bool fix_condition = (m_parent_mother->GetDirection() == LONG && current_price <= level_50) ||
                           (m_parent_mother->GetDirection() == SHORT && current_price >= level_50);
      if(fix_condition)
      {
         m_is_fixed = true;
         Log("فرزند اول فیکس شد: صد=" + DoubleToString(m_price100, _Digits) + ", زمان=" + TimeToString(TimeCurrent()));
         if(InpVisualDebug)
         {
            string arrow_name = "Debug_Arrow_Child1Fix_" + TimeToString(TimeCurrent()) + (m_is_test ? "_Test" : "");
            if(ObjectCreate(0, arrow_name, m_parent_mother->GetDirection() == LONG ? OBJ_ARROW_DOWN : OBJ_ARROW_UP, 0, TimeCurrent(), current_price))
            {
               ObjectSetInteger(0, arrow_name, OBJPROP_COLOR, m_parent_mother->GetDirection() == LONG ? clrGreen : clrRed);
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

   bool CheckFailure(double current_price)
   {
      bool fail_condition = (m_parent_mother->GetDirection() == LONG && current_price > m_parent_mother->GetPrice100()) ||
                            (m_parent_mother->GetDirection() == SHORT && current_price < m_parent_mother->GetPrice100());
      if(fail_condition)
      {
         Log("فرزند اول شکست خورد: قیمت=" + DoubleToString(current_price, _Digits) + ", زمان=" + TimeToString(TimeCurrent()));
         if(InpVisualDebug)
         {
            string label_name = "Debug_Label_Child1Fail_" + TimeToString(TimeCurrent()) + (m_is_test ? "_Test" : "");
            if(ObjectCreate(0, label_name, OBJ_TEXT, 0, TimeCurrent(), current_price))
            {
               ObjectSetString(0, label_name, OBJPROP_TEXT, "فرزند اول شکست خورد: قیمت=" + DoubleToString(current_price, _Digits));
               ObjectSetInteger(0, label_name, OBJPROP_COLOR, clrRed);
            }
         }
         return true;
      }
      return false;
   }

   bool CheckGoldenZone(double current_price, double &levels[])
   {
      if(StringFind(m_name, "Child2") < 0) return false;
      double zone_start = m_price100 + (m_price0 - m_price100) * levels[0] / 100.0;
      double zone_end = m_price100 + (m_price0 - m_price100) * levels[1] / 100.0;
      bool in_zone = (m_parent_mother->GetDirection() == LONG && current_price >= zone_start && current_price <= zone_end) ||
                     (m_parent_mother->GetDirection() == SHORT && current_price <= zone_start && current_price >= zone_end);
      if(in_zone && InpVisualDebug)
      {
         string rect_name = "Debug_Rectangle_GoldenZone_" + TimeToString(m_time100) + (m_is_test ? "_Test" : "");
         if(ObjectFind(0, rect_name) < 0)
         {
            if(ObjectCreate(0, rect_name, OBJ_RECTANGLE, 0, m_time100, zone_start, TimeCurrent(), zone_end))
            {
               ObjectSetInteger(0, rect_name, OBJPROP_COLOR, clrLightYellow);
               ObjectSetInteger(0, rect_name, OBJPROP_FILL, true);
               ObjectSetInteger(0, rect_name, OBJPROP_BGCOLOR, clrLightYellow);
               CheckObjectExists(rect_name);
            }
         }
      }
      return in_zone;
   }

   bool IsFixed() { return m_is_fixed; }
   bool IsSuccessChild2() { return m_is_success_child2; }
};

//+------------------------------------------------------------------+
//| کلاس CHipoStructure: مدیریت ساختار فیبوناچی                   |
//+------------------------------------------------------------------+
class CHipoStructure
{
private:
   ENUM_STRUCTURE_STATE m_state;
   ENUM_DIRECTION m_direction;
   CMotherFibo* m_mother;
   CChildFibo* m_child1;
   CChildFibo* m_child2;
   bool m_is_test;
   CPanel* m_panel;
   double m_break_levels[];
   double m_golden_zone[];
   string m_signal_id;
   datetime m_start_time;

   bool CheckObjectExists(string name)
   {
      for(int i = 0; i < 3; i++)
      {
         if(ObjectFind(0, name) >= 0) return true;
         Sleep(100);
      }
      Log("خطا: عدم رندر شیء " + name);
      return false;
   }

   void Log(string message)
   {
      if(InpEnableLog)
         CStructureManager::LogStatic(message + (m_is_test ? " [Test]" : ""));
   }

public:
   CHipoStructure(CPanel* panel, bool is_test)
   {
      m_state = SEARCHING;
      m_mother = NULL;
      m_child1 = NULL;
      m_child2 = NULL;
      m_is_test = is_test;
      m_panel = panel;
      m_start_time = TimeCurrent();
      string temp_levels[];
      int count = StringSplit(InpChild2BreakLevels, StringGetCharacter(",", 0), temp_levels);
      ArrayResize(m_break_levels, count);
      for(int i = 0; i < count; i++)
         m_break_levels[i] = StringToDouble(temp_levels[i]);
      count = StringSplit(InpGoldenZone, StringGetCharacter(",", 0), temp_levels);
      ArrayResize(m_golden_zone, count);
      for(int i = 0; i < count; i++)
         m_golden_zone[i] = StringToDouble(temp_levels[i]);
   }

   bool Start(ENUM_DIRECTION direction)
   {
      m_direction = direction;
      m_state = SEARCHING;
      m_start_time = TimeCurrent();
      string dir_str = m_direction == LONG ? "Long" : "Short";
      Log("شروع ساختار " + dir_str);
      if(m_panel && InpShowPanel)
         m_panel.UpdateCommand(dir_str + (m_is_test ? " [Test]" : ""));
      return true;
   }

   void OnNewBar()
   {
      datetime current_time = iTime(_Symbol, _Period, 0);
      if(m_state == SEARCHING)
      {
         CFractalFinder finder;
         SFractal fractal;
         if(m_direction == LONG)
            finder.FindRecentHigh(current_time, InpFractalLookback, InpFractalPeers, fractal);
         else
            finder.FindRecentLow(current_time, InpFractalLookback, InpFractalPeers, fractal);
         if(fractal.time == 0)
         {
            if(m_panel && InpShowPanel)
               m_panel.UpdateStatus("در انتظار فراکتال" + (m_is_test ? " [Test]" : ""));
            Log("در انتظار فراکتال");
            return;
         }
         m_mother = new CMotherFibo("HipoFibo_" + TimeToString(current_time) + "_Mother_" + (m_direction == LONG ? "Long" : "Short"),
                                    InpMotherColor, InpMotherLevels, m_direction, m_is_test);
         if(m_mother.Initialize(fractal, current_time))
         {
            m_state = MOTHER_ACTIVE;
            if(m_panel && InpShowPanel)
               m_panel.UpdateStatus("مادر در حال آپدیت لنگرگاه" + (m_is_test ? " [Test]" : ""));
         }
      }
      else if(m_state == MOTHER_ACTIVE)
      {
         m_mother.Update(current_time);
         if(InpMotherFixMode == CANDLE_CLOSE && m_mother.CheckFixingOnBar())
         {
            m_child1 = new CChildFibo("HipoFibo_" + TimeToString(current_time) + "_Child1_" + (m_direction == LONG ? "Long" : "Short"),
                                      InpChild1Color, InpChildLevels, m_mother, false, m_is_test);
            if(m_child1.Initialize(current_time))
            {
               m_state = CHILD1_ACTIVE;
               if(m_panel && InpShowPanel)
                  m_panel.UpdateStatus("مادر فیکس شد / منتظر فرزند اول" + (m_is_test ? " [Test]" : ""));
            }
         }
      }
      else if(m_state == CHILD1_ACTIVE)
      {
         m_child1.Update(current_time);
      }
      else if(m_state == CHILD2_ACTIVE)
      {
         m_child2.Update(current_time);
         double last_close = iClose(_Symbol, _Period, 0);
         double break_level = m_mother.GetPrice100() + (m_mother.GetPrice0() - m_mother.GetPrice100()) * m_break_levels[1] / 100.0;
         if((m_direction == LONG && last_close > break_level) ||
            (m_direction == SHORT && last_close < break_level))
         {
            m_state = FAILED;
            Log("ساختار " + (m_direction == LONG ? "Long" : "Short") + " شکست خورد: قیمت=" + DoubleToString(last_close, _Digits));
            if(m_panel && InpShowPanel)
               m_panel.UpdateStatus("ساختار شکست خورد" + (m_is_test ? " [Test]" : ""));
            if(InpVisualDebug)
            {
               string label_name = "Debug_Label_Failure_" + TimeToString(current_time) + (m_is_test ? "_Test" : "");
               if(ObjectCreate(0, label_name, OBJ_TEXT, 0, current_time, last_close))
               {
                  ObjectSetString(0, label_name, OBJPROP_TEXT, "ساختار " + (m_direction == LONG ? "Long" : "Short") + " شکست خورد");
                  ObjectSetInteger(0, label_name, OBJPROP_COLOR, clrRed);
               }
            }
            Stop();
         }
      }
   }

   SSignal OnTick()
   {
      SSignal signal;
      signal.type = "";
      signal.id = "";
      double current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(m_state == MOTHER_ACTIVE && InpMotherFixMode == PRICE_CROSS)
      {
         if(m_mother.CheckFixing(current_price))
         {
            m_child1 = new CChildFibo("HipoFibo_" + TimeToString(TimeCurrent()) + "_Child1_" + (m_direction == LONG ? "Long" : "Short"),
                                      InpChild1Color, InpChildLevels, m_mother, false, m_is_test);
            if(m_child1.Initialize(TimeCurrent()))
            {
               m_state = CHILD1_ACTIVE;
               if(m_panel && InpShowPanel)
                  m_panel.UpdateStatus("مادر فیکس شد / منتظر فرزند اول" + (m_is_test ? " [Test]" : ""));
            }
         }
      }
      else if(m_state == CHILD1_ACTIVE)
      {
         if(m_child1.CheckFixing(current_price))
         {
            m_child2 = new CChildFibo("HipoFibo_" + TimeToString(TimeCurrent()) + "_SuccessChild2_" + (m_direction == LONG ? "Long" : "Short"),
                                      InpChild2Color, InpChildLevels, m_mother, true, m_is_test);
            if(m_child2.Initialize(TimeCurrent()))
            {
               m_state = CHILD2_ACTIVE;
               if(m_panel && InpShowPanel)
                  m_panel.UpdateStatus("فرزند دوم (موفق) متولد شد" + (m_is_test ? " [Test]" : ""));
            }
         }
         else if(m_child1.CheckFailure(current_price))
         {
            double break_level_start = m_mother.GetPrice100() + (m_mother.GetPrice0() - m_mother.GetPrice100()) * m_break_levels[0] / 100.0;
            double break_level_end = m_mother.GetPrice100() + (m_mother.GetPrice0() - m_mother.GetPrice100()) * m_break_levels[1] / 100.0;
            bool in_break_zone = (m_direction == LONG && current_price >= break_level_start && current_price <= break_level_end) ||
                                 (m_direction == SHORT && current_price <= break_level_start && current_price >= break_level_end);
            if(in_break_zone)
            {
               m_child2 = new CChildFibo("HipoFibo_" + TimeToString(TimeCurrent()) + "_FailureChild2_" + (m_direction == LONG ? "Long" : "Short"),
                                         InpChild2Color, InpChildLevels, m_mother, false, m_is_test);
               if(m_child2.Initialize(TimeCurrent()))
               {
                  m_state = CHILD2_ACTIVE;
                  if(m_panel && InpShowPanel)
                     m_panel.UpdateStatus("فرزند دوم (ناموفق) متولد شد" + (m_is_test ? " [Test]" : ""));
               }
            }
         }
      }
      else if(m_state == CHILD2_ACTIVE)
      {
         if(m_child2.CheckGoldenZone(current_price, m_golden_zone))
         {
            signal.type = m_direction == LONG ? "Buy" : "Sell";
            signal.id = TimeToString(TimeCurrent()) + "_" + (m_direction == LONG ? "Long" : "Short") + "_" +
                        (m_child2.IsSuccessChild2() ? "Success" : "Failure");
            Log("سیگنال " + signal.type + ": ID=" + signal.id + ", قیمت=" + DoubleToString(current_price, _Digits));
            if(m_panel && InpShowPanel)
               m_panel.UpdateStatus("سیگنال " + signal.type + ": ID=" + signal.id + (m_is_test ? " [Test]" : ""));
            if(InpVisualDebug)
            {
               string arrow_name = "Debug_Arrow_Signal_" + TimeToString(TimeCurrent()) + (m_is_test ? "_Test" : "");
               if(ObjectCreate(0, arrow_name, m_direction == LONG ? OBJ_ARROW_UP : OBJ_ARROW_DOWN, 0, TimeCurrent(), current_price))
               {
                  ObjectSetInteger(0, arrow_name, OBJPROP_COLOR, clrGold);
                  CheckObjectExists(arrow_name); // خط ۸۸۸
               }
               string label_name = "Debug_Label_Signal_" + TimeToString(TimeCurrent()) + (m_is_test ? "_Test" : "");
               if(ObjectCreate(0, label_name, OBJ_TEXT, 0, TimeCurrent(), current_price))
               {
                  ObjectSetString(0, label_name, OBJPROP_TEXT, "سیگنال " + signal.type + ": ID=" + signal.id);
                  ObjectSetInteger(0, label_name, OBJPROP_COLOR, clrWhite);
               }
            }
            m_signal_id = signal.id;
         }
      }
      return signal;
   }

   void Stop()
   {
      if(m_mother) { m_mother.Delete(); delete m_mother; m_mother = NULL; }
      if(m_child1) { m_child1.Delete(); delete m_child1; m_child1 = NULL; }
      if(m_child2) { m_child2.Delete(); delete m_child2; m_child2 = NULL; }
      m_state = COMPLETED;
      Log("ساختار " + (m_direction == LONG ? "Long" : "Short") + " متوقف شد");
      if(m_panel && InpShowPanel)
         m_panel.UpdateStatus("ساختار متوقف شد" + (m_is_test ? " [Test]" : ""));
   }

   bool AcknowledgeSignal(string id)
   {
      if(m_signal_id == id)
      {
         Stop();
         return true;
      }
      return false;
   }

   ENUM_STRUCTURE_STATE GetState() { return m_state; }
   datetime GetStartTime() { return m_start_time; }
};

//+------------------------------------------------------------------+
//| کلاس CStructureManager: مدیر کل ساختارها                       |
//+------------------------------------------------------------------+
class CStructureManager
{
private:
   CHipoStructure* m_structures[];
   CPanel* m_panel;
   CTestPanel* m_test_panel;
   bool m_is_test_mode;
   datetime m_last_update;
   int m_max_families;
   SSignal m_last_signal;
   int m_log_handle;

   void Log(string message)
   {
      if(InpEnableLog && m_log_handle != INVALID_HANDLE)
      {
         FileWrite(m_log_handle, TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES | TIME_SECONDS) + ": " + message);
      }
   }

public:
   static void LogStatic(string message)
   {
      if(InpEnableLog)
      {
         int handle = FileOpen(InpLogFilePath, FILE_WRITE | FILE_TXT | FILE_COMMON);
         if(handle != INVALID_HANDLE)
         {
            FileWrite(handle, TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES | TIME_SECONDS) + ": " + message);
            FileClose(handle);
         }
      }
   }

   CStructureManager()
   {
      ArrayResize(m_structures, 0);
      m_is_test_mode = false;
      m_last_update = 0;
      m_max_families = InpMaxFamilies < 1 ? 2 : InpMaxFamilies;
      m_last_signal.type = "";
      m_last_signal.id = "";
      m_log_handle = InpEnableLog ? FileOpen(InpLogFilePath, FILE_WRITE | FILE_TXT | FILE_COMMON) : INVALID_HANDLE;
      m_panel = InpShowPanel ? new CPanel("HipoPanel", InpPanelCorner, InpPanelOffsetX < 0 ? 10 : InpPanelOffsetX,
                                          InpPanelOffsetY < 0 ? 20 : InpPanelOffsetY) : NULL;
      m_test_panel = NULL;
      if(m_panel) m_panel.Create();
      if(InpTestMode) EnableTestMode(true);
   }

   ~CStructureManager()
   {
      for(int i = 0; i < ArraySize(m_structures); i++)
      {
         m_structures[i].Stop();
         delete m_structures[i];
      }
      ArrayFree(m_structures);
      if(m_panel) { m_panel.Destroy(); delete m_panel; }
      if(m_test_panel) { m_test_panel.Destroy(); delete m_test_panel; }
      if(m_log_handle != INVALID_HANDLE) FileClose(m_log_handle);
   }

   void EnableTestMode(bool enable)
   {
      m_is_test_mode = enable;
      if(enable)
      {
         m_test_panel = new CTestPanel("HipoTestPanel", InpTestPanelCorner, InpTestPanelOffsetX < 0 ? 0 : InpTestPanelOffsetX,
                                       InpTestPanelOffsetY < 0 ? 20 : InpTestPanelOffsetY,
                                       InpTestPanelButtonColorLong, InpTestPanelButtonColorShort,
                                       InpTestPanelButtonColorStop, InpTestPanelBgColor);
         if(m_test_panel.Create())
            Log("حالت تست فعال شد");
         else
            Log("خطا: عدم ایجاد پنل تست");
      }
      else if(m_test_panel)
      {
         m_test_panel.Destroy();
         delete m_test_panel;
         m_test_panel = NULL;
         Log("حالت تست غیرفعال شد");
      }
   }

   bool CreateNewStructure(ENUM_DIRECTION direction)
   {
      if(m_is_test_mode) return false;
      for(int i = 0; i < ArraySize(m_structures); i++)
      {
         if(m_structures[i].GetState() != COMPLETED)
         {
            Log("خطا: ساختار فعال موجود است");
            if(m_panel && InpShowPanel)
               m_panel.UpdateStatus("ساختار فعال موجود است");
            return false;
         }
      }
      CleanupOldestStructure();
      CHipoStructure* structure = new CHipoStructure(m_panel, false);
      if(structure.Start(direction))
      {
         ArrayResize(m_structures, ArraySize(m_structures) + 1);
         m_structures[ArraySize(m_structures) - 1] = structure;
         return true;
      }
      delete structure;
      return false;
   }

   bool ProcessTestCommand(string command)
   {
      if(!m_is_test_mode) return false;
      if(command == "StartLong" || command == "StartShort")
      {
         for(int i = 0; i < ArraySize(m_structures); i++)
         {
            if(m_structures[i].GetState() != COMPLETED)
            {
               Log("خطا: ساختار فعال موجود است");
               if(m_panel && InpShowPanel)
                  m_panel.UpdateTestStatus("ساختار فعال موجود است");
               return false;
            }
         }
         CleanupOldestStructure();
         CHipoStructure* structure = new CHipoStructure(m_panel, true);
         ENUM_DIRECTION direction = command == "StartLong" ? LONG : SHORT;
         if(structure.Start(direction))
         {
            ArrayResize(m_structures, ArraySize(m_structures) + 1);
            m_structures[ArraySize(m_structures) - 1] = structure;
            Log("حالت تست: دستور " + command + " دریافت شد");
            if(m_panel && InpShowPanel)
               m_panel.UpdateTestStatus("دستور " + command + " دریافت شد");
            return true;
         }
         delete structure;
         return false;
      }
      else if(command == "Stop")
      {
         for(int i = 0; i < ArraySize(m_structures); i++)
         {
            if(m_structures[i].GetState() != COMPLETED)
            {
               m_structures[i].Stop();
               delete m_structures[i];
               ArrayRemove(m_structures, i, 1);
               Log("حالت تست: ساختار متوقف شد");
               if(m_panel && InpShowPanel)
                  m_panel.UpdateTestStatus("ساختار متوقف شد");
               return true;
            }
         }
         return false;
      }
      return false;
   }

   void OnNewBar()
   {
      for(int i = 0; i < ArraySize(m_structures); i++)
         m_structures[i].OnNewBar();
      m_last_update = TimeCurrent();
   }

   SSignal OnTick()
   {
      SSignal signal;
      signal.type = "";
      signal.id = "";
      for(int i = 0; i < ArraySize(m_structures); i++)
      {
         SSignal temp = m_structures[i].OnTick();
         if(temp.id != "")
         {
            signal.type = temp.type;
            signal.id = temp.id;
            m_last_signal = temp;
         }
      }
      m_last_update = TimeCurrent();
      return signal;
   }

   bool AcknowledgeSignal(string id)
   {
      for(int i = 0; i < ArraySize(m_structures); i++)
         if(m_structures[i].AcknowledgeSignal(id))
            return true;
      return false;
   }

   void RecoverState()
   {
      if(TimeCurrent() - m_last_update > PeriodSeconds(_Period))
      {
         Log("بازیابی وضعیت: آپدیت از دست رفته");
         OnNewBar();
      }
   }

   void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
   {
      if(id == CHARTEVENT_OBJECT_CLICK && m_is_test_mode && m_test_panel != NULL)
      {
         string command;
         if(m_test_panel.OnButtonClick(sparam, command))
            ProcessTestCommand(command);
      }
   }

   void CleanupOldestStructure()
   {
      if(ArraySize(m_structures) >= m_max_families)
      {
         int oldest_index = -1;
         datetime oldest_time = TimeCurrent();
         for(int i = 0; i < ArraySize(m_structures); i++)
         {
            if(m_structures[i].GetState() == COMPLETED && m_structures[i].GetStartTime() < oldest_time)
            {
               oldest_index = i;
               oldest_time = m_structures[i].GetStartTime();
            }
         }
         if(oldest_index >= 0)
         {
            m_structures[oldest_index].Stop();
            delete m_structures[oldest_index];
            ArrayRemove(m_structures, oldest_index, 1);
         }
      }
   }

   SSignal GetLastSignal()
   {
      SSignal signal = m_last_signal;
      m_last_signal.type = "";
      m_last_signal.id = "";
      return signal;
   }
};

//+------------------------------------------------------------------+
//| توابع عمومی کتابخانه                                           |
//+------------------------------------------------------------------+
CStructureManager* g_manager = NULL;

void OnInit()
{
   g_manager = new CStructureManager();
}

void OnDeinit(const int reason)
{
   if(g_manager) delete g_manager;
}

void OnTick()
{
   if(g_manager) g_manager->OnTick();
}

void OnNewBar()
{
   if(g_manager) g_manager->OnNewBar();
}

bool StartStructure(ENUM_DIRECTION direction)
{
   if(g_manager) return g_manager->CreateNewStructure(direction);
   return false;
}

SSignal GetSignal()
{
   if(g_manager) return g_manager->GetLastSignal();
   SSignal signal = {"", ""};
   return signal;
}

bool AcknowledgeSignal(string id)
{
   if(g_manager) return g_manager->AcknowledgeSignal(id);
   return false;
}

void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   if(g_manager) g_manager->OnChartEvent(id, lparam, dparam, sparam);
}
