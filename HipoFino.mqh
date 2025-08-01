//+------------------------------------------------------------------+
//|                                                  HipoFino.mqh    |
//|                                     محصولی از: Hipo Algorithm      |
//|                                           نسخه: ۲.۰.۰ (معماری دو لایه) |
//|                                           تاریخ: ۲۰۲۵/۰۸/۰۱        |
//|      موتور اصلی اکسپرت HipoFino با معماری دو لایه سیگنال‌گیری      |
//+------------------------------------------------------------------+

#ifndef HIPO_FINO_MQH
#define HIPO_FINO_MQH

#include <Trade\Trade.mqh>
#include <HipoFibonacci.mqh>
#include "HipoDashboard.mqh"
#include "HipoMomentumFractals.mqh"
#include "HipoCvtChannel.mqh"
#include "HipoInitialStopLoss.mqh"
#include "HipoSignalDecker.mqh" // <<-- فایل جدید اضافه شد

//+------------------------------------------------------------------+
//| ثابت‌ها و ساختارها                                              |
//+------------------------------------------------------------------+
#define MA_FILTER_BUFFER (3 * _Point)

struct SCandleTime
  {
   datetime           htf_last_candle;  // زمان آخرین کندل HTF
   datetime           ltf_last_candle;  // زمان آخرین کندل LTF
  };

//+------------------------------------------------------------------+
//| کلاس CHipoFino: موتور اصلی اکسپرت (نسخه کامل بازنویسی شده)      |
//+------------------------------------------------------------------+
class CHipoFino
  {
private:
   // --- تنظیمات اصلی ---
   ENUM_TIMEFRAMES    m_htf;
   ENUM_TIMEFRAMES    m_ltf;
   int                m_htf_fast_ema, m_htf_slow_ema, m_htf_signal;
   int                m_ltf_fast_ema, m_ltf_slow_ema, m_ltf_signal;
   double             m_risk_percent;
   long               m_magic_number;

   // ... (سایر متغیرهای شما بدون تغییر باقی می‌مانند) ...
   // --- تنظیمات فیلتر سشن ---
   bool               m_use_session_filter;
   bool               m_tokyo_session;
   bool               m_london_session;
   bool               m_newyork_session;
   string             m_custom_session_start;
   string             m_custom_session_end;

   // --- تنظیمات تریلینگ استاپ ---
   ENUM_STOP_METHOD   m_stop_method;
   double             m_sar_step;
   double             m_sar_maximum;
   int                m_min_lookback;
   int                m_max_lookback;
   int                m_fractal_bars;
   int                m_fractal_buffer_pips;
   bool               m_show_stop_line;
   bool               m_show_fractals;
   
   // --- هندل‌ها و متغیرهای داخلی ---
   int                m_htf_macd_handle;
   int                m_ltf_macd_handle;
   SCandleTime        m_candle_times;
   string             m_log_buffer;
   datetime           m_last_flush_time;
   ENUM_HIPO_STATE    m_state;
   ulong              m_position_ticket;
   ENUM_DIRECTION     m_active_direction;
   CHipoMomentumFractals* m_fractals;
   CHipoCvtChannel* m_trailing;
   CHipoInitialStopLoss* m_initial_sl_manager;
   
   // <<-- لایه اول (دیده‌بان) اضافه شد
   CHipoSignalDecker* m_signal_decker;

   // --- تنظیمات مشترک برای استاپ اولیه و تریلینگ استاپ ---
   ENUM_TIMEFRAMES    m_atr_ma_timeframe;
   ENUM_MA_METHOD     m_ma_method;
   int                m_ma_period;
   ENUM_APPLIED_PRICE m_ma_price;
   int                m_atr_period;
   double             m_atr_multiplier;

   ENUM_TIMEFRAMES    m_simple_fractal_timeframe;
   int                m_simple_fractal_bars;
   int                m_simple_fractal_peers;
   double             m_simple_fractal_buffer_pips;

   // --- متغیرهای فیلتر ورود با MA ---
   bool               m_use_ma_entry_filter;
   int                m_ma_filter_period;
   ENUM_MA_METHOD     m_ma_filter_method;
   ENUM_APPLIED_PRICE m_ma_filter_price;
   int                m_ma_filter_handle;

   // --- متغیرهای جدید برای مدیریت معامله ---
   bool               m_use_partial_tp;
   string             m_partial_tp_percentages;
   double             m_fixed_tp_rr;
   bool               m_use_trailing_stop;
   double             m_trailing_activation_rr;

   // --- متغیرهای وضعیت برای معامله باز ---
   double             m_initial_sl_price;
   double             m_initial_risk_pips;
   double             m_entry_price;
   double             m_initial_volume;
   bool               m_is_trailing_active;
   int                m_partial_tp_stage_hit;
   double             m_tp_levels_price[3];
   
   // --- متغیرهای وضعیت برای فیلتر MA ---
   double             m_entry_candidate_price;
   double             m_invalidation_sl_price;
   bool               m_ma_filter_armed;
   
   // --- متغیرهای وضعیت برای پلن B و تایمر ---
   int                m_timeout_counter;
   bool               m_pinbar_detected;
   double             m_pinbar_high;
   double             m_pinbar_low;
   datetime           m_pinbar_time;
   CTrade             m_trade;

   //+------------------------------------------------------------------+
   //| تابع لاگ‌گیری                                                  |
   //+------------------------------------------------------------------+
   void Log(string message)
     {
      string log_entry = TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES|TIME_SECONDS) + ": " + message + "\n";
      m_log_buffer += log_entry;
      Print("HipoFino: ", log_entry); // اضافه کردن پیشوند برای تشخیص لاگ‌ها
     }

   //+------------------------------------------------------------------+
   //| تابع فلاش لاگ به فایل                                          |
   //+------------------------------------------------------------------+
   void FlushLog()
     {
      if(m_log_buffer == "")
         return;
      int handle = FileOpen("HipoFino_Log.txt", FILE_WRITE|FILE_TXT|FILE_COMMON);
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
   //| تابع پردازش فیلتر ورود (نسخه نهایی با نمایشگر کلد اسکن)
   //+------------------------------------------------------------------+
   void ProcessMAFilter(bool new_candle)
     {
      // ... (منطق داخلی این تابع بدون تغییر) ...
      // <<! نکته مهم: هرجا در این تابع m_state = HIPO_IDLE; قرار می‌گیرد،
      // باید خط m_signal_decker.Reset(); را نیز اضافه کنیم.
      
      double current_ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double current_bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

      // شرط ابطال
      if((m_active_direction == LONG && current_bid <= m_invalidation_sl_price) ||
         (m_active_direction == SHORT && current_ask >= m_invalidation_sl_price))
        {
         Log("شرط ابطال فیلتر MA فعال شد. قیمت به صفر مادر رسید. عملیات لغو شد.");
         HFiboStopCurrentStructure();
         if(m_signal_decker != NULL) m_signal_decker.Reset(); // <<-- ریست لایه اول
         m_state = HIPO_IDLE;
         return;
        }

      // شکست پین‌بار
      if(m_pinbar_detected)
        {
         bool breakout = false;
         if(m_active_direction == LONG && current_ask > m_pinbar_high)
            breakout = true;
         if(m_active_direction == SHORT && current_bid < m_pinbar_low)
            breakout = true;

         if(breakout)
           {
            Log("پلن B شلیک کرد! شکست سقف/کف پین بار تایید شد.");
            string signal_type = (m_active_direction == LONG) ? "Buy" : "Sell";
            SSignal fake_signal = {signal_type, "Pinbar_Breakout_Signal"};
            if(SendTrade(fake_signal, (signal_type == "Buy" ? current_ask : current_bid), m_invalidation_sl_price))
              {
               m_state = HIPO_MANAGING_POSITION;
               HFiboAcknowledgeSignal(fake_signal.id);
               // در اینجا ریست نمی‌کنیم چون وارد مدیریت معامله شدیم
              }
            else
              {
               Log("ارسال معامله بعد از شکست پین بار ناموفق بود.");
               HFiboStopCurrentStructure();
               if(m_signal_decker != NULL) m_signal_decker.Reset(); // <<-- ریست لایه اول
               m_state = HIPO_IDLE;
              }
            return;
           }
        }

      if(!new_candle)
         return;

      // ... (بقیه منطق تابع با اضافه کردن ریست در نقاط لازم) ...
      
      // تایم اوت
      if(m_timeout_counter > 50)
        {
         Log("زمان انتظار برای فیلتر MA تمام شد. عملیات لغو شد.");
         HFiboStopCurrentStructure();
         if(m_signal_decker != NULL) m_signal_decker.Reset(); // <<-- ریست لایه اول
         m_state = HIPO_IDLE;
         return;
        }
      m_timeout_counter++;
      
      // ... (بقیه تابع)
     }
     
   // ... (سایر توابع شما مثل IsNewCandle, GetMacdBias, CalculateVolume, و غیره بدون تغییر) ...
   bool IsNewCandle(ENUM_TIMEFRAMES timeframe, datetime &last_candle_time)
   {
       //... بدون تغییر
       return false;
   }
   ENUM_MACD_BIAS GetMacdBias(int macd_handle, ENUM_TIMEFRAMES timeframe)
   {
       //... بدون تغییر
       return MACD_NEUTRAL;
   }
   double CalculateVolume(double entry_price, double sl_price)
   {
       //... بدون تغییر
       return 0.01;
   }
   bool IsSessionActive()
   {
       //... بدون تغییر
       return true;
   }
   void ResetTradeManagementState()
   {
       //... بدون تغییر
   }
   void CalculateAndDrawTPs()
   {
       //... بدون تغییر
   }
   void ManagePartialTPs()
   {
       //... بدون تغییر
   }
   void CreateTPVisuals()
   {
       //... بدون تغییر
   }
   void UpdateTPVisuals(int stage_hit)
   {
       //... بدون تغییر
   }
   void ClearTPVisuals()
   {
       //... بدون تغییر
   }

public:
   //+------------------------------------------------------------------+
   //| سازنده کلاس (Constructor) بازنویسی شده نهایی
   //+------------------------------------------------------------------+
   CHipoFino(ENUM_TIMEFRAMES htf, ENUM_TIMEFRAMES ltf, int htf_fast_ema, int htf_slow_ema, int htf_signal,
             int ltf_fast_ema, int ltf_slow_ema, int ltf_signal, double risk_percent,
             long magic_number,
             bool use_session_filter, bool tokyo, bool london, bool newyork, string custom_start, string custom_end,
             bool use_partial_tp, string partial_tp_percentages, double fixed_tp_rr,
             bool use_trailing_stop, double trailing_activation_rr,
             ENUM_STOP_METHOD stop_method, double sar_step, double sar_max,
             int min_lookback, int max_lookback, int fractal_bars, int fractal_buffer_pips,
             bool show_stop_line, bool show_fractals,
             // پارامترهای فیلتر ورود MA
             bool use_ma_entry_filter, int ma_filter_period, ENUM_MA_METHOD ma_filter_method, ENUM_APPLIED_PRICE ma_filter_price,
             // پارامترهای استاپ اولیه
             ENUM_INITIAL_STOP_METHOD initial_stop_method, int initial_sl_buffer_pips,
             ENUM_TIMEFRAMES atr_ma_timeframe, ENUM_MA_METHOD ma_method, int ma_period, ENUM_APPLIED_PRICE ma_price,
             int atr_period, double atr_multiplier,
             ENUM_TIMEFRAMES simple_fractal_timeframe, int simple_fractal_bars, int simple_fractal_peers, double simple_fractal_buffer_pips)
     {
      // ... (تمام مقداردهی‌های اولیه شما بدون تغییر) ...
      
      // <<-- مقداردهی اولیه برای شی جدید
      m_signal_decker = NULL;

      // ... (بقیه سازنده) ...
     }
     
   //+------------------------------------------------------------------+
   //| تابع راه‌اندازی
   //+------------------------------------------------------------------+
   bool Initialize()
     {
      m_htf_macd_handle = iMACD(_Symbol, m_htf, m_htf_fast_ema, m_htf_slow_ema, m_htf_signal, PRICE_CLOSE);
      m_ltf_macd_handle = iMACD(_Symbol, m_ltf, m_ltf_fast_ema, m_ltf_slow_ema, m_ltf_signal, PRICE_CLOSE);
      if(m_htf_macd_handle == INVALID_HANDLE || m_ltf_macd_handle == INVALID_HANDLE)
        {
         Log("خطا: ایجاد هندل مکدی ناموفق بود");
         return false;
        }

      // <<-- راه‌اندازی لایه اول (دیده‌بان)
      m_signal_decker = new CHipoSignalDecker();
      if(m_signal_decker == NULL || !m_signal_decker.Initialize(m_htf, m_htf_fast_ema, m_htf_slow_ema, m_htf_signal))
      {
          Log("خطا: راه‌اندازی Signal Decker ناموفق بود");
          return false;
      }

      // ... (بقیه منطق راه‌اندازی شما بدون تغییر) ...
      
      Log("موتور اصلی با موفقیت راه‌اندازی شد");
      return true;
     }
     
   //+------------------------------------------------------------------+
   //| تابع توقف                                                      |
   //+------------------------------------------------------------------+
   void Deinitialize()
     {
      // <<-- توقف و حذف شی لایه اول
      if(m_signal_decker != NULL)
      {
          m_signal_decker.Deinitialize();
          delete m_signal_decker;
          m_signal_decker = NULL;
      }
      
      // ... (بقیه منطق توقف شما بدون تغییر) ...
      
      Log("موتور اصلی متوقف شد");
     }
     
   //+------------------------------------------------------------------+
   //| تابع ارسال معامله (SendTrade) بازنویسی شده                      |
   //+------------------------------------------------------------------+
   bool SendTrade(SSignal &signal, double entry_price, double initial_mother_zero)
     {
      // ... (این تابع بدون تغییر باقی می‌ماند) ...
      return true;
     }
     
   //+------------------------------------------------------------------+
   //| تابع پردازش تیک (نسخه نهایی با معماری دو لایه)                 |
   //+------------------------------------------------------------------+
   void OnTick()
     {
      if(TimeCurrent() - m_last_flush_time >= 5)
         FlushLog();

      bool new_htf_candle = IsNewCandle(m_htf, m_candle_times.htf_last_candle);
      bool new_ltf_candle = IsNewCandle(m_ltf, m_candle_times.ltf_last_candle);

      if(new_htf_candle || new_ltf_candle)
        {
         HFiboOnNewBar(); 
         if(m_fractals != NULL)
            m_fractals.Calculate();
        }

      ENUM_MACD_BIAS htf_bias = GetMacdBias(m_htf_macd_handle, m_htf);
      ENUM_MACD_BIAS ltf_bias = GetMacdBias(m_ltf_macd_handle, m_ltf);
      if(g_dashboard != NULL)
         g_dashboard.UpdateMacdBias(htf_bias, ltf_bias, m_state);

      // <<-- لایه اول (Signal Decker) فقط در کندل جدید HTF کار می‌کند
      if(new_htf_candle && IsSessionActive() && m_signal_decker != NULL)
        {
         m_signal_decker.OnNewHtfCandle(htf_bias);
        }

      // << ================================================================== >>
      // << =========== منطق State Machine جدید و بازنویسی شده ================ >>
      // << ================================================================== >>
      switch(m_state)
        {
         case HIPO_IDLE:
           {
            // در حالت بیکار، ما (لایه دوم) دائما از لایه اول سوال می‌کنیم
            // که آیا ساختاری برای ما آماده کرده است یا نه.
            if(m_signal_decker != NULL && m_signal_decker.GetStatus() == DECKER_STRUCTURE_ACTIVE)
              {
               Log("لایه اول یک ساختار فعال را گزارش داد. شروع فرآیند بررسی...");
               
               // 1. چراغ‌ها را روشن می‌کنیم
               HFiboSetVisibility(true);
               
               // 2. وضعیت را از لایه اول می‌گیریم و خودمان را آپدیت می‌کنیم
               m_active_direction = m_signal_decker.GetActiveDirection();
               m_state = HIPO_WAITING_FOR_HIPO;
               Log("تغییر وضعیت به HIPO_WAITING_FOR_HIPO برای جهت " + EnumToString(m_active_direction));
              }
            break;
           }

         case HIPO_WAITING_FOR_HIPO:
           {
            // شرط ابطال ۱: کتابخانه فیبو ساختار را باطل کرده
            if(HFiboIsStructureBroken())
              {
               Log("کتابخانه فیبو ساختار را باطل کرد. بازگشت به حالت بیکار.");
               if(m_signal_decker != NULL) m_signal_decker.Reset(); // به لایه اول خبر بده
               m_state = HIPO_IDLE;
               break;
              }

            // شرط ابطال ۲: روند اصلی برگشته
            if((m_active_direction == LONG && htf_bias == MACD_BEARISH) ||
               (m_active_direction == SHORT && htf_bias == MACD_BULLISH))
              {
               Log("روند اصلی HTF برگشت. ساختار فعلی متوقف می‌شود.");
               HFiboStopCurrentStructure();
               if(m_signal_decker != NULL) m_signal_decker.Reset(); // به لایه اول خبر بده
               m_state = HIPO_IDLE;
               break;
              }

            // شرط اصلی: آیا سیگنال ورود صادر شده؟
            SSignal signal = HFiboGetSignal();
            if(signal.id != "")
              {
               // اگر فیلتر MA غیرفعال است، مستقیم وارد معامله شو
               if(!m_use_ma_entry_filter)
                 {
                  double mother_zero = HFiboGetMotherZeroPoint();
                  double entry_price = (signal.type == "Buy") ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
                  if(SendTrade(signal, entry_price, mother_zero))
                    {
                     m_state = HIPO_MANAGING_POSITION;
                     Log("وارد حالت مدیریت معامله شد");
                     // Acknowledge در SendTrade انجام می‌شود
                    }
                  else
                    {
                     Log("خطا در ارسال معامله، بازگشت به حالت بیکار");
                     HFiboStopCurrentStructure();
                     if(m_signal_decker != NULL) m_signal_decker.Reset(); // به لایه اول خبر بده
                     m_state = HIPO_IDLE;
                    }
                 }
               // اگر فیلتر MA فعال است، وارد فاز انتظار برای فیلتر شو
               else
                 {
                  Log("سیگنال فیبوناچی دریافت شد. ورود به فاز انتظار برای فیلتر MA...");
                  ResetTradeManagementState();
                  m_timeout_counter = 0;
                  m_invalidation_sl_price = HFiboGetMotherZeroPoint();
                  m_entry_candidate_price = (signal.type == "Buy") ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);

                  if(m_invalidation_sl_price == 0)
                    {
                     Log("خطا: نقطه صفر مادر برای شرط ابطال یافت نشد. عملیات لغو شد.");
                     HFiboStopCurrentStructure();
                     if(m_signal_decker != NULL) m_signal_decker.Reset(); // به لایه اول خبر بده
                     m_state = HIPO_IDLE;
                    }
                  else
                    {
                     m_state = HIPO_WAITING_FOR_MA_CROSS;
                    }
                 }
              }
            break;
           }

         case HIPO_WAITING_FOR_MA_CROSS:
           {
            // این تابع حالا داخل خودش در صورت نیاز لایه اول را ریست می‌کند
            ProcessMAFilter(new_ltf_candle);
            break;
           }

         case HIPO_MANAGING_POSITION:
           {
            if(!PositionSelectByTicket(m_position_ticket))
              {
               Log("معامله بسته شد، بازگشت به حالت بیکار");
               HFiboAcknowledgeSignal(""); 
               if(m_trailing != NULL)
                  m_trailing.UpdateVisuals(0.0, POSITION_TYPE_BUY);
               ResetTradeManagementState();
               if(m_signal_decker != NULL) m_signal_decker.Reset(); // به لایه اول خبر بده
               m_state = HIPO_IDLE;
               break;
              }
            
            // ... (بقیه منطق مدیریت معامله بدون تغییر) ...
            
            break;
           }
        }
     }
};

#endif
//+------------------------------------------------------------------+
