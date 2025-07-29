//+------------------------------------------------------------------+
//|                                           HipoInitialStopLoss.mqh |
//|                              محصولی از: Hipo Algorithm           |
//|                              نسخه: ۱.۰.۰                          |
//|                              تاریخ: ۲۰۲۵/۰۷/۲۸                   |
//| کتابخانه مدیریت و محاسبه حد ضرر اولیه                          |
//+------------------------------------------------------------------+

#ifndef HIPO_INITIAL_STOP_LOSS_MQH
#define HIPO_INITIAL_STOP_LOSS_MQH

#include <Trade\Trade.mqh>      // برای توابع معاملاتی
#include <Indicators\Indicators.mqh> // برای توابع عمومی اندیکاتورها مثل iMA و iATR
// #include <Indicators\MovingAverages.mqh> // 👈 این لازم نیست، Indicators.mqh کفایت میکنه
// #include <Indicators\ATR.mqh>           // 👈 این هم لازم نیست، Indicators.mqh کفایت میکنه

//+------------------------------------------------------------------+
//| Enum برای انتخاب روش استاپ لاس اولیه (کپی شده از HipoFinoEA)     |
//+------------------------------------------------------------------+
enum ENUM_INITIAL_STOP_METHOD
{
   INITIAL_STOP_MOTHER_ZERO,      // روش فعلی: صفر مادر
   INITIAL_STOP_ATR_MA,           // روش ترکیب ATR و میانگین متحرک
   INITIAL_STOP_SIMPLE_FRACTAL    // روش فراکتال ساده
};

//+------------------------------------------------------------------+
//| کلاس CHipoInitialStopLoss                                       |
//+------------------------------------------------------------------+
class CHipoInitialStopLoss
{
private:
   // --- تنظیمات ورودی ---
   ENUM_INITIAL_STOP_METHOD m_initial_stop_method;
   int    m_initial_sl_buffer_pips;

   // تنظیمات روش ATR و میانگین متحرک
   ENUM_TIMEFRAMES m_atr_ma_timeframe;
   ENUM_MA_METHOD m_ma_method;
   int    m_ma_period;
   ENUM_APPLIED_PRICE m_ma_price;
   int    m_atr_period;
   double m_atr_multiplier;
   
   // تنظیمات روش فراکتال ساده
   ENUM_TIMEFRAMES m_simple_fractal_timeframe;
   int    m_simple_fractal_bars;
   int    m_simple_fractal_peers; // تعداد کندل‌های چپ/راست برای فراکتال ساده
   double m_simple_fractal_buffer_pips;

   // --- هندل اندیکاتورها ---
   int    m_ma_handle;
   int    m_atr_handle;

   // --- لاگ‌گیری ---
   string m_log_buffer;
   datetime m_last_flush_time;

   //+------------------------------------------------------------------+
   //| تابع لاگ‌گیری                                                  |
   //+------------------------------------------------------------------+
   void Log(string message)
   {
      string log_entry = TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES|TIME_SECONDS) + ": [InitialSL] " + message + "\n";
      m_log_buffer += log_entry;
      Print(log_entry);
   }
   
   //+------------------------------------------------------------------+
   //| تابع فلاش لاگ به فایل                                          |
   //+------------------------------------------------------------------+
   void FlushLog()
   {
      if(m_log_buffer == "") return;
      int handle = FileOpen("HipoInitialStopLoss_Log.txt", FILE_WRITE|FILE_TXT|FILE_COMMON);
      if(handle != INVALID_HANDLE)
      {
         FileSeek(handle, 0, SEEK_END);
         FileWrite(handle, m_log_buffer);
         FileClose(handle);
         m_log_buffer = "";
      }
      m_last_flush_time = TimeCurrent();
   }

   //+------------------------------------------------------------------+
   //| تابع محاسبه استاپ لاس با روش ATR و میانگین متحرک             |
   //+------------------------------------------------------------------+
   double CalculateATRMAStopLoss(ENUM_DIRECTION trade_direction, double entry_price)
   {
      double ma_value[];
      double atr_value[];
      ArraySetAsSeries(ma_value, true);
      ArraySetAsSeries(atr_value, true);
      
      // گرفتن داده های ATR و MA روی تایم فریم مشخص شده
      if(CopyBuffer(m_ma_handle, 0, 0, 2, ma_value) < 2 || 
         CopyBuffer(m_atr_handle, 0, 0, 2, atr_value) < 2)
      {
         Log("خطا در دریافت داده های MA یا ATR برای محاسبه استاپ لاس ATR/MA.");
         return 0.0;
      }
      
      double current_ma = ma_value[0];
      double current_atr = atr_value[0];
      
      if (current_atr == 0) 
      {
          Log("خطا: مقدار ATR صفر است.");
          return 0.0;
      }

      double stop_loss_price = 0.0;
      if (trade_direction == LONG) // خرید
      {
         stop_loss_price = current_ma - (m_atr_multiplier * current_atr);
      }
      else // فروش
      {
         stop_loss_price = current_ma + (m_atr_multiplier * current_atr);
      }
      
      Log("SL توسط ATR/MA محاسبه شد: " + DoubleToString(stop_loss_price, _Digits) + 
          " (MA: " + DoubleToString(current_ma, _Digits) + ", ATR: " + DoubleToString(current_atr, _Digits) + ")");
      return NormalizeDouble(stop_loss_price, _Digits);
   }

   //+------------------------------------------------------------------+
   //| تابع محاسبه استاپ لاس با روش فراکتال ساده                    |
   //+------------------------------------------------------------------+
   double CalculateSimpleFractalStopLoss(ENUM_DIRECTION trade_direction, double entry_price)
   {
      double fractal_price = 0.0;
      int total_bars = Bars(_Symbol, m_simple_fractal_timeframe);
      if (total_bars < m_simple_fractal_bars + m_simple_fractal_peers * 2 + 1) // حداقل تعداد کندل لازم برای فراکتال
      {
          Log("تعداد کندل کافی برای فراکتال ساده در تایم‌فریم " + EnumToString(m_simple_fractal_timeframe) + " وجود ندارد.");
          return 0.0;
      }
      
      // جستجو در بازه m_simple_fractal_bars کندل قبل
      // از کندل m_simple_fractal_peers شروع میکنیم (کندل جاری 0، قبلی 1، و غیره)
      for (int i = m_simple_fractal_peers; i < total_bars - m_simple_fractal_peers; i++) 
      {
         if (trade_direction == LONG) // دنبال Low Fractal برای SL خرید
         {
            double current_low = iLow(_Symbol, m_simple_fractal_timeframe, i);
            bool is_fractal_low = true;
            // بررسی m_simple_fractal_peers کندل در هر دو طرف
            for (int j = 1; j <= m_simple_fractal_peers; j++) 
            {
               if (iLow(_Symbol, m_simple_fractal_timeframe, i - j) <= current_low || iLow(_Symbol, m_simple_fractal_timeframe, i + j) <= current_low)
               {
                  is_fractal_low = false;
                  break;
               }
            }
            if (is_fractal_low)
            {
               fractal_price = current_low;
               break; // اولین فراکتال معتبر پیدا شد
            }
         }
         else // SHORT - دنبال High Fractal برای SL فروش
         {
            double current_high = iHigh(_Symbol, m_simple_fractal_timeframe, i);
            bool is_fractal_high = true;
            // بررسی m_simple_fractal_peers کندل در هر دو طرف
            for (int j = 1; j <= m_simple_fractal_peers; j++) 
            {
               if (iHigh(_Symbol, m_simple_fractal_timeframe, i - j) >= current_high || iHigh(_Symbol, m_simple_fractal_timeframe, i + j) >= current_high)
               {
                  is_fractal_high = false;
                  break;
               }
            }
            if (is_fractal_high)
            {
               fractal_price = current_high;
               break; // اولین فراکتال معتبر پیدا شد
            }
         }
      }

      if (fractal_price == 0.0) 
      {
         Log("فراکتال ساده معتبر یافت نشد.");
         return 0.0; 
      }

      double stop_loss_price = 0.0;
      if (trade_direction == LONG)
      {
         stop_loss_price = fractal_price - m_simple_fractal_buffer_pips * _Point;
      }
      else // SHORT
      {
         stop_loss_price = fractal_price + m_simple_fractal_buffer_pips * _Point;
      }
      
      Log("SL توسط فراکتال ساده محاسبه شد: " + DoubleToString(stop_loss_price, _Digits) + 
          " (Fractal Price: " + DoubleToString(fractal_price, _Digits) + ")");
      return NormalizeDouble(stop_loss_price, _Digits);
   }


public:
   //+------------------------------------------------------------------+
   //| سازنده کلاس                                                     |
   //+------------------------------------------------------------------+
   CHipoInitialStopLoss(ENUM_INITIAL_STOP_METHOD initial_stop_method, int initial_sl_buffer_pips,
                        ENUM_TIMEFRAMES atr_ma_timeframe, ENUM_MA_METHOD ma_method, int ma_period, ENUM_APPLIED_PRICE ma_price,
                        int atr_period, double atr_multiplier,
                        ENUM_TIMEFRAMES simple_fractal_timeframe, int simple_fractal_bars, int simple_fractal_peers, double simple_fractal_buffer_pips)
   {
      m_initial_stop_method = initial_stop_method;
      m_initial_sl_buffer_pips = initial_sl_buffer_pips;
      
      m_atr_ma_timeframe = atr_ma_timeframe;
      m_ma_method = ma_method;
      m_ma_period = ma_period;
      m_ma_price = ma_price;
      m_atr_period = atr_period;
      m_atr_multiplier = atr_multiplier;
      
      m_simple_fractal_timeframe = simple_fractal_timeframe;
      m_simple_fractal_bars = simple_fractal_bars;
       m_simple_fractal_peers = simple_fractal_peers;  // 👈 اشتباه املایی اینجا بود
      m_simple_fractal_buffer_pips = simple_fractal_buffer_pips;

      m_ma_handle = INVALID_HANDLE;
      m_atr_handle = INVALID_HANDLE;
      m_log_buffer = "";
      m_last_flush_time = 0;
   }
   
   //+------------------------------------------------------------------+
   //| تابع راه‌اندازی                                                 |
   //+------------------------------------------------------------------+
   bool Initialize()
   {
      if(m_initial_stop_method == INITIAL_STOP_ATR_MA)
      {
         m_ma_handle = iMA(_Symbol, m_atr_ma_timeframe, m_ma_period, 0, m_ma_method, m_ma_price);
         m_atr_handle = iATR(_Symbol, m_atr_ma_timeframe, m_atr_period);
         if(m_ma_handle == INVALID_HANDLE || m_atr_handle == INVALID_HANDLE)
         {
            Log("خطا: ایجاد هندل MA یا ATR برای استاپ لاس اولیه ناموفق بود.");
            return false;
         }
      }
      Log("مدیریت استاپ لاس اولیه با موفقیت راه‌اندازی شد. روش انتخابی: " + EnumToString(m_initial_stop_method));
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| تابع توقف                                                       |
   //+------------------------------------------------------------------+
   void Deinitialize()
   {
      if(m_ma_handle != INVALID_HANDLE)
         IndicatorRelease(m_ma_handle);
      if(m_atr_handle != INVALID_HANDLE)
         IndicatorRelease(m_atr_handle);
      FlushLog();
      Log("مدیریت استاپ لاس اولیه متوقف شد.");
   }
   
   //+------------------------------------------------------------------+
   //| تابع اصلی برای گرفتن استاپ لاس نهایی                            |
   //+------------------------------------------------------------------+
   double GetFinalStopLoss(ENUM_DIRECTION trade_direction, double entry_price, double mother_zero_point)
   {
      if(TimeCurrent() - m_last_flush_time >= 5)
         FlushLog();

      double calculated_sl = 0.0;

      // مرحله ۱: محاسبه SL بر اساس روش انتخابی
      if (m_initial_stop_method == INITIAL_STOP_ATR_MA)
      {
         calculated_sl = CalculateATRMAStopLoss(trade_direction, entry_price);
      }
      else if (m_initial_stop_method == INITIAL_STOP_SIMPLE_FRACTAL)
      {
         calculated_sl = CalculateSimpleFractalStopLoss(trade_direction, entry_price);
      }
      else // INITIAL_STOP_MOTHER_ZERO
      {
         calculated_sl = mother_zero_point;
         Log("SL اولیه بر اساس صفر مادر محاسبه شد: " + DoubleToString(calculated_sl, _Digits));
      }

      // اگر calculated_sl نامعتبر بود (0.0 برگشت)، یک مقدار پیش‌فرض برگردان
      if (calculated_sl == 0.0) {
          Log("هشدار: محاسبه استاپ لاس بر اساس روش " + EnumToString(m_initial_stop_method) + " ناموفق بود. بازگشت 0.0");
          return 0.0; 
      }
      
      double final_sl_price = calculated_sl; // شروع با SL محاسبه شده

      // مرحله ۲: اعمال منطق اولویت با صفر مادر (اگر روش انتخابی صفر مادر نبود)
      // اگر mother_zero_point هم 0.0 بود، یعنی صفر مادر هم معتبر نیست، پس این بخش اجرا نمیشود
      if (m_initial_stop_method != INITIAL_STOP_MOTHER_ZERO && mother_zero_point != 0.0)
      {
         if (trade_direction == LONG) // خرید
         {
            // برای خرید، SL باید پایین‌تر از قیمت ورود باشد (مثلا 1.2000). SL نزدیک‌تر به ورود = بالاتر (مثلا 1.2010)
            // اگر SL محاسبه شده از صفر مادر (که پایین‌تر است) بالاتر بود (یعنی فاصله کمتری تا ورود داشت)، 
            // و صفر مادر هم منطقی بود (پایین‌تر از entry_price)
            if (mother_zero_point < entry_price && final_sl_price < mother_zero_point) 
            {
                // این یعنی SL محاسبه شده بدتر از صفر مادر بود (خیلی پایین‌تر)
                // پس صفر مادر را انتخاب می‌کنیم (که نزدیک‌تر است و ریسک کمتری دارد)
                final_sl_price = mother_zero_point;
                Log("اولویت با صفر مادر بود (خرید)، SL به: " + DoubleToString(final_sl_price, _Digits) + " تغییر یافت.");
            }
         }
         else // فروش (SHORT)
         {
            // برای فروش، SL باید بالاتر از قیمت ورود باشد (مثلا 1.2000). SL نزدیک‌تر به ورود = پایین‌تر (مثلا 1.1990)
            // اگر SL محاسبه شده از صفر مادر (که بالاتر است) پایین‌تر بود (یعنی فاصله کمتری تا ورود داشت)،
            // و صفر مادر هم منطقی بود (بالاتر از entry_price)
            if (mother_zero_point > entry_price && final_sl_price > mother_zero_point)
            {
                // این یعنی SL محاسبه شده بدتر از صفر مادر بود (خیلی بالاتر)
                // پس صفر مادر را انتخاب می‌کنیم (که نزدیک‌تر است و ریسک کمتری دارد)
                final_sl_price = mother_zero_point;
                Log("اولویت با صفر مادر بود (فروش)، SL به: " + DoubleToString(final_sl_price, _Digits) + " تغییر یافت.");
            }
         }
      }
      
      // اضافه کردن بافر پیپ به SL نهایی
      if (trade_direction == LONG)
      {
         final_sl_price -= m_initial_sl_buffer_pips * _Point;
      }
      else // SHORT
      {
         final_sl_price += m_initial_sl_buffer_pips * _Point;
      }

      Log("SL نهایی برای معامله نوع " + EnumToString(trade_direction) + " تنظیم شد: " + DoubleToString(final_sl_price, _Digits));
      return NormalizeDouble(final_sl_price, _Digits);
   }
};

#endif
