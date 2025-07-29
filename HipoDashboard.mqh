//+------------------------------------------------------------------+
//|                                              HipoDashboard.mqh |
//|                           محصولی از: Hipo Algorithm              |
//|                                     نسخه: ۱.۱.۰ (بازنویسی شده)    |
//|                                      تاریخ: ۲۰۲۵/۰۷/۲۸            |
//|         کتابخانه گرافیکی برای نمایش پنل و وضعیت‌ها                |
//+------------------------------------------------------------------+

#ifndef HIPO_DASHBOARD_MQH
#define HIPO_DASHBOARD_MQH

#include <Trade\Trade.mqh>
#include "HipoFino.mqh" // forward declaration

//+------------------------------------------------------------------+
//| ثابت‌ها و ساختارها                                              |
//+------------------------------------------------------------------+
enum ENUM_HIPO_STATE
{
   HIPO_IDLE,                  // حالت بیکار
   HIPO_WAITING_FOR_HIPO,      // در انتظار سیگنال فیبوناچی
   HIPO_WAITING_FOR_MA_CROSS,  // در انتظار فیلتر نهایی
   HIPO_MANAGING_POSITION      // مدیریت معامله باز
};

enum ENUM_MACD_BIAS
{
   MACD_BULLISH, // صعودی
   MACD_BEARISH, // نزولی
   MACD_NEUTRAL  // خنثی
};

//+------------------------------------------------------------------+
//| کلاس CHipoDashboard                                             |
//+------------------------------------------------------------------+
class CHipoDashboard
{
private:
   bool              m_show_panel;
   bool              m_show_macd;
   ENUM_TIMEFRAMES   m_htf;
   ENUM_TIMEFRAMES   m_ltf;
   int               m_htf_macd_handle;
   int               m_ltf_macd_handle;
   string            m_panel_name;
   int               m_flash_counter;
   long              m_magic_number;
   
   // متغیرهای جدید برای نمایشگر "کلد اسکن"
   string            m_scan_title_name;
   string            m_scan_symbol_name;
   string            m_scan_counter_name;

   //+------------------------------------------------------------------+
   //| تابع ایجاد لیبل
   //+------------------------------------------------------------------+
   bool CreateLabel(string name, string text, int x, int y, color clr, int font_size, string font)
   {
      if(!ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0))
         return false;
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
      ObjectSetString(0, name, OBJPROP_TEXT, text);
      ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, font_size);
      ObjectSetString(0, name, OBJPROP_FONT, font);
      ObjectSetInteger(0, name, OBJPROP_ZORDER, 1);
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| تابع ایجاد دایره برای نمایش وضعیت
   //+------------------------------------------------------------------+
   bool CreateCircle(string name, int x, int y, color clr)
   {
      if(!ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0))
         return false;
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
      ObjectSetString(0, name, OBJPROP_TEXT, "●");
      ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 10);
      ObjectSetString(0, name, OBJPROP_FONT, "Arial");
      ObjectSetInteger(0, name, OBJPROP_ZORDER, 1);
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| تابع ایجاد پس‌زمینه پنل
   //+------------------------------------------------------------------+
   bool CreateBackground(string name, int x, int y)
   {
      if(!ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0))
         return false;
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
      ObjectSetInteger(0, name, OBJPROP_XSIZE, 300);
      ObjectSetInteger(0, name, OBJPROP_YSIZE, 120);
      ObjectSetInteger(0, name, OBJPROP_BGCOLOR, clrDarkSlateGray);
      ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, name, OBJPROP_ZORDER, -1);
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| تابع ایجاد هدر پنل
   //+------------------------------------------------------------------+
   bool CreateHeader(string name, int x, int y)
   {
      if(!ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0))
         return false;
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
      ObjectSetInteger(0, name, OBJPROP_XSIZE, 300);
      ObjectSetInteger(0, name, OBJPROP_YSIZE, 20);
      ObjectSetInteger(0, name, OBJPROP_BGCOLOR, clrGoldenrod);
      ObjectSetInteger(0, name, OBJPROP_ZORDER, 0);
      return true;
   }

public:
   //+------------------------------------------------------------------+
   //| سازنده کلاس
   //+------------------------------------------------------------------+
   CHipoDashboard(bool show_panel, bool show_macd, ENUM_TIMEFRAMES htf, ENUM_TIMEFRAMES ltf, long magic_number)
   {
      m_show_panel = show_panel;
      m_show_macd = show_macd;
      m_htf = htf;
      m_ltf = ltf;
      m_htf_macd_handle = INVALID_HANDLE;
      m_ltf_macd_handle = INVALID_HANDLE;
      m_panel_name = "HipoFino_Panel";
      m_flash_counter = 0;
      m_magic_number = magic_number;
   }
   
   //+------------------------------------------------------------------+
   //| تابع راه‌اندازی
   //+------------------------------------------------------------------+
   bool Initialize()
   {
      if(m_show_panel)
      {
         if(!CreateBackground(m_panel_name + "_Bg", 10, 20) ||
            !CreateHeader(m_panel_name + "_Header", 10, 20) ||
            !CreateLabel(m_panel_name + "_Title", "HipoFino ", 120, 19, clrWhite, 13, "Calibri Bold") ||
            !CreateLabel(m_panel_name + "_HTF", "HTF Trend (" + EnumToString(m_htf) + ")", 30, 50, clrWhite, 9, "Calibri") ||
            !CreateLabel(m_panel_name + "_LTF", "LTF Trigger (" + EnumToString(m_ltf) + ")", 30, 70, clrWhite, 9, "Calibri") ||
            !CreateLabel(m_panel_name + "_Status", "وضعیت: در انتظار سیگنال...", 20, 90, clrWhite, 12, "Calibri") ||
            !CreateCircle(m_panel_name + "_HTF_Circle", 20, 50, clrLightGray) ||
            !CreateCircle(m_panel_name + "_LTF_Circle", 20, 70, clrLightGray))
         {
            Print("خطا در ایجاد پنل گرافیکی");
            return false;
         }
         
         // --- ایجاد لیبل های نمایشگر "کلد اسکن" ---
         m_scan_title_name = m_panel_name + "_Scan_Title";
         m_scan_symbol_name = m_panel_name + "_Scan_Symbol";
         m_scan_counter_name = m_panel_name + "_Scan_Counter";
         
         CreateLabel(m_scan_title_name, "Cold Scan:", 180, 70, clrGoldenrod, 9, "Calibri Bold");
         // مختصات این دو لیبل طوری تنظیم شده که اول سیمبل بیاد بعد شمارنده
         CreateLabel(m_scan_symbol_name, "", 245, 70, clrWhite, 12, "Wingdings");
         CreateLabel(m_scan_counter_name, "", 260, 70, clrWhite, 9, "Calibri");
      }
      
      // ... بقیه کد Initialize برای مکدی بدون تغییر است ...
      if(m_show_macd)
      {
         m_htf_macd_handle = iMACD(_Symbol, m_htf, InpHTFFastEMA, InpHTFSlowEMA, InpHTFSignal, PRICE_CLOSE);
         m_ltf_macd_handle = iMACD(_Symbol, m_ltf, InpLTFFastEMA, InpLTFSlowEMA, InpLTFSignal, PRICE_CLOSE);
         if(m_htf_macd_handle == INVALID_HANDLE || m_ltf_macd_handle == INVALID_HANDLE)
         {
            Print("خطا در ایجاد هندل مکدی برای نمایش");
            return false;
         }
         if(ChartIndicatorAdd(0, 2, m_htf_macd_handle) < 0 || ChartIndicatorAdd(0, 1, m_ltf_macd_handle) < 0)
         {
            Print("خطا در افزودن اندیکاتورهای مکدی به چارت");
            return false;
         }
      }
      
      Print("داشبورد گرافیکی با موفقیت راه‌اندازی شد");
      return true;
   }
   
   //+------------------------------------------------------------------+
//| تابع توقف (نسخه اصلاح شده)
//+------------------------------------------------------------------+
void Deinitialize()
{
   if(m_show_panel)
   {
      // پاک کردن تک تک اجزای پنل با نام دقیق آنها
      ObjectDelete(0, m_panel_name + "_Bg");
      ObjectDelete(0, m_panel_name + "_Header");
      ObjectDelete(0, m_panel_name + "_Title");
      ObjectDelete(0, m_panel_name + "_HTF");
      ObjectDelete(0, m_panel_name + "_LTF");
      ObjectDelete(0, m_panel_name + "_Status");
      ObjectDelete(0, m_panel_name + "_HTF_Circle");
      ObjectDelete(0, m_panel_name + "_LTF_Circle");
      
      // پاک کردن لیبل های "کلد اسکن"
      ObjectDelete(0, m_scan_title_name);
      ObjectDelete(0, m_scan_symbol_name);
      ObjectDelete(0, m_scan_counter_name);
   }
   
   if(m_show_macd)
   {
      if(m_htf_macd_handle != INVALID_HANDLE)
         IndicatorRelease(m_htf_macd_handle);
      if(m_ltf_macd_handle != INVALID_HANDLE)
         IndicatorRelease(m_ltf_macd_handle);
   }
   Print("داشبورد گرافیکی متوقف شد");
}
   //+------------------------------------------------------------------+
   //| تابع به‌روزرسانی نمایشگر وضعیت "کلد اسکن" (جدید)
   //+------------------------------------------------------------------+
   void UpdateScanStatus(int counter, int plan_status) // plan_status: 0=خالی, 1=پلن A, 2=پلن B
   {
      if(!m_show_panel) return;

      if(plan_status == 0) // پاک کردن نمایشگر
      {
         ObjectSetString(0, m_scan_symbol_name, OBJPROP_TEXT, "");
         ObjectSetString(0, m_scan_counter_name, OBJPROP_TEXT, "");
         return;
      }
      
      // نمایش سیمبل پلن
      if(plan_status == 1) // پلن A (MA) مسلح شده
      {
         ObjectSetString(0, m_scan_symbol_name, OBJPROP_TEXT, ShortToString(236));
         ObjectSetInteger(0, m_scan_symbol_name, OBJPROP_COLOR, clrDodgerBlue);
         // وقتی پلن A مسلح است، شمارنده نمایش داده نمیشود
         ObjectSetString(0, m_scan_counter_name, OBJPROP_TEXT, ""); 
      }
      else if(plan_status == 2) // پلن B (Pinbar) پیدا شده
      {
         ObjectSetString(0, m_scan_symbol_name, OBJPROP_TEXT, ShortToString(125));
         ObjectSetInteger(0, m_scan_symbol_name, OBJPROP_COLOR, clrGold);
         // وقتی پلن B فعال است، شمارنده نمایش داده میشود
         ObjectSetString(0, m_scan_counter_name, OBJPROP_TEXT, (string)counter); 
      }
      else // حالتی که فقط شمارنده نمایش داده شود (وقتی هیچ پلنی فعال نیست)
      {
         ObjectSetString(0, m_scan_symbol_name, OBJPROP_TEXT, "");
         ObjectSetString(0, m_scan_counter_name, OBJPROP_TEXT, (string)counter);
      }
   }

   //+------------------------------------------------------------------+
   //| تابع به‌روزرسانی وضعیت کلی پنل
   //+------------------------------------------------------------------+
   void UpdateMacdBias(ENUM_MACD_BIAS htf_bias, ENUM_MACD_BIAS ltf_bias, ENUM_HIPO_STATE state)
   {
      if(m_show_panel)
      {
         m_flash_counter = (m_flash_counter + 1) % 40;
         color status_color = (m_flash_counter < 20) ? clrLightYellow : clrWhite;
         
         ObjectSetInteger(0, m_panel_name + "_HTF_Circle", OBJPROP_COLOR,
                          htf_bias == MACD_BULLISH ? clrGreen :
                          htf_bias == MACD_BEARISH ? clrRed : clrLightGray);
         ObjectSetInteger(0, m_panel_name + "_LTF_Circle", OBJPROP_COLOR,
                          ltf_bias == MACD_BULLISH ? clrGreen :
                          ltf_bias == MACD_BEARISH ? clrRed : clrLightGray);
         
         string status_text;
         switch(state)
         {
            case HIPO_IDLE:
               status_text = "وضعیت: در انتظار سیگنال...";
               break;
            case HIPO_WAITING_FOR_HIPO:
               status_text = "وضعیت: دستور ارسال شد...";
               break;
            case HIPO_WAITING_FOR_MA_CROSS:
               status_text = "وضعیت: در حال اسکن برای ورود...";
               break;
            case HIPO_MANAGING_POSITION:
               status_text = "وضعیت: پوزیشن #" + (string)m_magic_number + " فعال است.";
               break;
         }
         
         ObjectSetString(0, m_panel_name + "_Status", OBJPROP_TEXT, status_text);
         ObjectSetInteger(0, m_panel_name + "_Status", OBJPROP_COLOR, status_color);
         
         // اگر در حالت انتظار نیستیم، نمایشگر کلد اسکن را پاک کن
         if(state != HIPO_WAITING_FOR_MA_CROSS)
         {
            UpdateScanStatus(0, 0);
         }
      }
   }
   
   //+------------------------------------------------------------------+
   //| تابع به‌روزرسانی کلی چارت
   //+------------------------------------------------------------------+
   void Update()
   {
      if(m_show_panel)
         ChartRedraw(0);
   }
};

#endif
