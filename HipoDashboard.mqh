//+------------------------------------------------------------------+
//|                                                  HipoDashboard.mqh |
//|                              محصولی از: Hipo Algorithm           |
//|                              نسخه: ۱.۰.۰                          |
//|                              تاریخ: ۲۰۲۵/۰۷/۲۵                   |
//| کتابخانه گرافیکی برای نمایش پنل و مکدی‌ها                      |
//+------------------------------------------------------------------+

#ifndef HIPO_DASHBOARD_MQH
#define HIPO_DASHBOARD_MQH
//| شامل کردن کتابخانه‌ها                                           |
//+------------------------------------------------------------------+
#include <Trade\Trade.mqh>
#include <HipoFibonacci.mqh>
#include "HipoFino.mqh"
#include "HipoDashboard.mqh"
#include "HipoMomentumFractals.mqh"
#include "HipoCvtChannel.mqh"

//+------------------------------------------------------------------+
//| ثابت‌ها و ساختارها                                             |
//+------------------------------------------------------------------+
enum ENUM_HIPO_STATE
{
   HIPO_IDLE,              // حالت بیکار
   HIPO_WAITING_FOR_HIPO,  // در انتظار سیگنال فیبوناچی
   HIPO_MANAGING_POSITION  // مدیریت معامله باز
};

enum ENUM_MACD_BIAS
{
   MACD_BULLISH,  // صعودی
   MACD_BEARISH,  // نزولی
   MACD_NEUTRAL   // خنثی
};

//+------------------------------------------------------------------+
//| کلاس CHipoDashboard:مدیریت پنل و نمایش مکدی‌ها                |
//+------------------------------------------------------------------+
class CHipoDashboard
{
private:
   bool m_show_panel;        // نمایش پنل
   bool m_show_macd;         // نمایش مکدی‌ها
   ENUM_TIMEFRAMES m_htf;    // تایم‌فریم HTF
   ENUM_TIMEFRAMES m_ltf;    // تایم‌فریم LTF
   int m_htf_macd_handle;    // هندل مکدی HTF
   int m_ltf_macd_handle;    // هندل مکدی LTF
   string m_panel_name;      // نام پنل
   int m_flash_counter;      // شمارشگر فلاش برای انیمیشن
   long m_magic_number;      // شماره جادویی (Magic Number)

   //+------------------------------------------------------------------+
   //| تابع ایجاد لیبل                                               |
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
   //| تابع ایجاد دایره برای نمایش وضعیت                             |
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
   //| تابع ایجاد پس‌زمینه پنل                                       |
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
   //| تابع ایجاد هدر پنل                                            |
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
   
   //+------------------------------------------------------------------+
   //| تابع ایجاد خط طلایی زیر هدر                                   |
   //+------------------------------------------------------------------+
   bool CreateHeaderLine(string name, int x, int y)
   {
      if(!ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0))
         return false;
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
      ObjectSetInteger(0, name, OBJPROP_XSIZE, 300);
      ObjectSetInteger(0, name, OBJPROP_YSIZE,0.5);
      ObjectSetInteger(0, name, OBJPROP_BGCOLOR, clrGoldenrod);
      ObjectSetInteger(0, name, OBJPROP_ZORDER, 0);
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| تابع ایجاد اندیکاتور مکدی                                    |
   //+------------------------------------------------------------------+
   bool CreateMacdIndicator(ENUM_TIMEFRAMES timeframe, int handle, int subwindow)
   {
      if(handle == INVALID_HANDLE) return false;
      string name = (timeframe == m_htf) ? "HipoFino_MACD_HTF" : "HipoFino_MACD_LTF";
      int window = ChartIndicatorAdd(0, subwindow, handle);
      if(window < 0)
      {
         Print("خطا در افزودن اندیکاتور مکدی: ", timeframe);
         return false;
      }
      return true;
   }

public:
   //+------------------------------------------------------------------+
   //| سازنده کلاس                                                   |
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
   //| تابع راه‌اندازی                                              |
   //+------------------------------------------------------------------+
   bool Initialize()
   {
      if(m_show_panel)
      {
         if(!CreateBackground(m_panel_name + "_Bg", 10, 20) ||
            !CreateHeader(m_panel_name + "_Header", 10, 20) ||
            !CreateHeaderLine(m_panel_name + "_HeaderLine", 10, 40) ||
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
      }
      
      if(m_show_macd)
      {
         m_htf_macd_handle = iMACD(_Symbol, m_htf, InpHTFFastEMA, InpHTFSlowEMA, InpHTFSignal, PRICE_CLOSE);
         m_ltf_macd_handle = iMACD(_Symbol, m_ltf, InpLTFFastEMA, InpLTFSlowEMA, InpLTFSignal, PRICE_CLOSE);
         if(m_htf_macd_handle == INVALID_HANDLE || m_ltf_macd_handle == INVALID_HANDLE)
         {
            Print("خطا در ایجاد هندل مکدی برای نمایش");
            return false;
         }
         if(!CreateMacdIndicator(m_htf, m_htf_macd_handle, 2) ||
            !CreateMacdIndicator(m_ltf, m_ltf_macd_handle, 1))
         {
            Print("خطا در افزودن اندیکاتورهای مکدی به چارت");
            return false;
         }
      }
      
      Print("داشبورد گرافیکی با موفقیت راه‌اندازی شد");
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| تابع توقف                                                    |
   //+------------------------------------------------------------------+
   void Deinitialize()
   {
      if(m_show_panel)
      {
         ObjectDelete(0, m_panel_name + "_Bg");
         ObjectDelete(0, m_panel_name + "_Header");
         ObjectDelete(0, m_panel_name + "_HeaderLine");
         ObjectDelete(0, m_panel_name + "_Title");
         ObjectDelete(0, m_panel_name + "_HTF");
         ObjectDelete(0, m_panel_name + "_LTF");
         ObjectDelete(0, m_panel_name + "_Status");
         ObjectDelete(0, m_panel_name + "_HTF_Circle");
         ObjectDelete(0, m_panel_name + "_LTF_Circle");
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
   //| تابع به‌روزرسانی وضعیت مکدی‌ها و پنل                         |
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
         switch( state)
         {
            case HIPO_IDLE:
               status_text = "وضعیت: در انتظار سیگنال...";
               break;
            case HIPO_WAITING_FOR_HIPO:
               status_text = "وضعیت: دستور ارسال شد. در انتظار پاسخ HipoLib...";
               break;
            case HIPO_MANAGING_POSITION:
               status_text = "وضعیت: پوزیشن #" + IntegerToString(m_magic_number) + " فعال است. در حال مانیتورینگ...";
               break;
         }
         
         ObjectSetString(0, m_panel_name + "_Status", OBJPROP_TEXT, status_text);
         ObjectSetInteger(0, m_panel_name + "_Status", OBJPROP_COLOR, status_color);
      }
   }
   
   //+------------------------------------------------------------------+
   //| تابع به‌روزرسانی کلی                                         |
   //+------------------------------------------------------------------+
   void Update()
   {
      if(m_show_panel)
         ChartRedraw(0);
   }
};

#endif
