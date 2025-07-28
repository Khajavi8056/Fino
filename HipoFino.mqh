//+------------------------------------------------------------------+
//|                                                    HipoFino.mqh  |
//|                              محصولی از: Hipo Algorithm           |
//|                              نسخه: ۱.۳.۰                          |
//|                              تاریخ: ۲۰۲۵/۰۷/۲۷                   |
//| موتور اصلی اکسپرت HipoFino با مدیریت معامله پیشرفته      |
//+------------------------------------------------------------------+

#ifndef HIPO_FINO_MQH
#define HIPO_FINO_MQH

#include <Trade\Trade.mqh>
#include <HipoFibonacci.mqh>
#include "HipoDashboard.mqh"
#include "HipoMomentumFractals.mqh"
#include "HipoCvtChannel.mqh"
#include "HipoInitialStopLoss.mqh" 
//+------------------------------------------------------------------+
//| ثابت‌ها و ساختارها                                             |
//+------------------------------------------------------------------+
// ساختار برای ذخیره زمان کندل‌ها
struct SCandleTime
{
   datetime htf_last_candle;  // زمان آخرین کندل HTF
   datetime ltf_last_candle;  // زمان آخرین کندل LTF
};

//+------------------------------------------------------------------+
//| کلاس CHipoFino: موتور اصلی اکسپرت (نسخه کامل بازنویسی شده)      |
//+------------------------------------------------------------------+
class CHipoFino
{
private:
   // --- تنظیمات اصلی ---
   ENUM_TIMEFRAMES m_htf;
   ENUM_TIMEFRAMES m_ltf;
   int    m_htf_fast_ema, m_htf_slow_ema, m_htf_signal;
   int    m_ltf_fast_ema, m_ltf_slow_ema, m_ltf_signal;
   double m_risk_percent;
   int    m_sl_buffer_pips;
   long   m_magic_number;

   // --- تنظیمات فیلتر سشن ---
   bool   m_use_session_filter;
   bool   m_tokyo_session;
   bool   m_london_session;
   bool   m_newyork_session;
   string m_custom_session_start;
   string m_custom_session_end;

   // --- تنظیمات تریلینگ استاپ ---
   ENUM_STOP_METHOD m_stop_method;
   double m_sar_step;
   double m_sar_maximum;
   int    m_min_lookback;
   int    m_max_lookback;
   int    m_fractal_bars;
   int    m_fractal_buffer_pips;
   bool   m_show_stop_line;
   bool   m_show_fractals;

   // --- هندل‌ها و متغیرهای داخلی ---
   int    m_htf_macd_handle;
   int    m_ltf_macd_handle;
   SCandleTime m_candle_times;
   string m_log_buffer;
   datetime m_last_flush_time;
   ENUM_HIPO_STATE m_state;
   ulong  m_position_ticket;
   ENUM_DIRECTION m_active_direction;
   CHipoMomentumFractals* m_fractals;
   CHipoCvtChannel* m_trailing;
   CHipoInitialStopLoss* m_initial_sl_manager;
   // --- متغیرهای جدید برای مدیریت معامله ---
   bool   m_use_partial_tp;
   string m_partial_tp_percentages;
   double m_fixed_tp_rr;
   bool   m_use_trailing_stop;
   double m_trailing_activation_rr;

   // --- متغیرهای وضعیت برای معامله باز ---
   double m_initial_sl_price;
   double m_initial_risk_pips;
   double m_entry_price;
   double m_initial_volume;
   bool   m_is_trailing_active;
   int    m_partial_tp_stage_hit;
   double m_tp_levels_price[3];
   
   CTrade m_trade;

   //+------------------------------------------------------------------+
   //| تابع لاگ‌گیری                                                  |
   //+------------------------------------------------------------------+
   void Log(string message)
   {
      string log_entry = TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES|TIME_SECONDS) + ": " + message + "\n";
      m_log_buffer += log_entry;
      Print(log_entry);
   }
   
   //+------------------------------------------------------------------+
   //| تابع فلاش لاگ به فایل                                          |
   //+------------------------------------------------------------------+
   void FlushLog()
   {
      if(m_log_buffer == "") return;
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
   //| تابع بررسی کندل جدید                                           |
   //+------------------------------------------------------------------+
   bool IsNewCandle(ENUM_TIMEFRAMES timeframe, datetime &last_candle_time)
   {
      datetime current_candle = iTime(_Symbol, timeframe, 0);
      if(current_candle != last_candle_time)
      {
         last_candle_time = current_candle;
         return true;
      }
      return false;
   }
   
   //+------------------------------------------------------------------+
   //| تابع دریافت وضعیت مکدی                                        |
   //+------------------------------------------------------------------+
   ENUM_MACD_BIAS GetMacdBias(int macd_handle, ENUM_TIMEFRAMES timeframe)
   {
      double macd[], signal[];
      ArraySetAsSeries(macd, true);
      ArraySetAsSeries(signal, true);
      if(CopyBuffer(macd_handle, 0, 1, 1, macd) <= 0 ||
         (timeframe == m_htf && CopyBuffer(macd_handle, 1, 1, 1, signal) <= 0))
      {
         Log("خطا در دریافت داده‌های مکدی برای تایم‌فریم: " + EnumToString(timeframe));
         return MACD_NEUTRAL;
      }
      
      if(timeframe == m_htf)
      {
         if(macd[0] > signal[0])
            return MACD_BULLISH;
         else if(macd[0] < signal[0])
            return MACD_BEARISH;
         return MACD_NEUTRAL;
      }
      else // LTF
      {
         if(macd[0] < 0)
            return MACD_BULLISH;
         else if(macd[0] > 0)
            return MACD_BEARISH;
         return MACD_NEUTRAL;
      }
   }
   
   //+------------------------------------------------------------------+
   //| تابع محاسبه حجم معامله                                        |
   //+------------------------------------------------------------------+
   double CalculateVolume(double entry_price, double sl_price)
   {
      double account_balance = AccountInfoDouble(ACCOUNT_BALANCE);
      double risk_amount = account_balance * m_risk_percent / 100.0;
      double pip_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      double pip_distance = MathAbs(entry_price - sl_price) / _Point;
      if(pip_value == 0 || pip_distance == 0)
      {
         Log("خطا: ارزش پیپ یا فاصله حد ضرر صفر است");
         return 0.0;
      }
      double volume = risk_amount / (pip_distance * pip_value);
      double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      double max_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
      volume = MathMax(min_lot, MathMin(max_lot, volume));
      return NormalizeDouble(volume, 2);
   }
   
   //+------------------------------------------------------------------+
   //| تابع بررسی فعال بودن سشن معاملاتی                             |
   //+------------------------------------------------------------------+
   bool IsSessionActive()
   {
      if(!m_use_session_filter) return true;
      
      datetime gmt_time = TimeGMT();
      MqlDateTime time_struct;
      TimeToStruct(gmt_time, time_struct);
      int hour = time_struct.hour;
      int minute = time_struct.min;
      int current_time = hour * 60 + minute;
      
      int tokyo_start = 0, tokyo_end = 9 * 60;
      int london_start = 8 * 60, london_end = 17 * 60;
      int newyork_start = 13 * 60, newyork_end = 22 * 60;
      
      string custom_parts[];
      int custom_start = 0, custom_end = 0;
      if(StringSplit(m_custom_session_start, ':', custom_parts) == 2)
         custom_start = (int)StringToInteger(custom_parts[0]) * 60 + (int)StringToInteger(custom_parts[1]);
      if(StringSplit(m_custom_session_end, ':', custom_parts) == 2)
         custom_end = (int)StringToInteger(custom_parts[0]) * 60 + (int)StringToInteger(custom_parts[1]);
      
      bool in_session = false;
      if(m_tokyo_session && current_time >= tokyo_start && current_time < tokyo_end)
         in_session = true;
      else if(m_london_session && current_time >= london_start && current_time < london_end)
         in_session = true;
      else if(m_newyork_session && current_time >= newyork_start && current_time < newyork_end)
         in_session = true;
      else if(custom_start != custom_end && 
              ((custom_start < custom_end && current_time >= custom_start && current_time < custom_end) ||
               (custom_start > custom_end && (current_time >= custom_start || current_time < custom_end))))
         in_session = true;
      
      if(!in_session)
         Log("خارج از سشن معاملاتی مجاز");
      return in_session;
   }

   // --- توابع خصوصی جدید برای مدیریت معامله ---
   void ResetTradeManagementState()
   {
      m_initial_sl_price = 0;
      m_initial_risk_pips = 0;
      m_entry_price = 0;
      m_initial_volume = 0;
      m_is_trailing_active = false;
      m_partial_tp_stage_hit = 0;
      ArrayInitialize(m_tp_levels_price, 0.0);
      ClearTPVisuals();
   }

   void CalculateAndDrawTPs()
   {
      if(!m_use_partial_tp || m_initial_risk_pips <= 0) return;

      string percentages_str[];
      int count = StringSplit(m_partial_tp_percentages, ',', percentages_str);
      if(count == 0) return;

      double initial_risk_usd = m_initial_risk_pips * SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE) * m_initial_volume;
      if(initial_risk_usd <= 0) return;
      
      double first_percent = StringToDouble(percentages_str[0]);
      if(first_percent <= 0) return;

      double volume_to_close_1 = m_initial_volume * (first_percent / 100.0);
      if(volume_to_close_1 < SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN)) volume_to_close_1 = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      
      double profit_per_pip_v1 = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE) * volume_to_close_1;
      if(profit_per_pip_v1 <= 0) return;
      
      double required_pips = initial_risk_usd / profit_per_pip_v1;
      double rr_calc = required_pips / m_initial_risk_pips;
      
      ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      for(int i=0; i < count && i < 3; i++)
      {
         double target_rr = (i == 0) ? rr_calc : rr_calc * (i + 1);
         double target_pips = m_initial_risk_pips * target_rr;
         if(pos_type == POSITION_TYPE_BUY)
            m_tp_levels_price[i] = m_entry_price + (target_pips * _Point);
         else
            m_tp_levels_price[i] = m_entry_price - (target_pips * _Point);
      }
      CreateTPVisuals();
   }

   void ManagePartialTPs()
   {
      if(!m_use_partial_tp) return;
      
      string percentages_str[];
      int num_levels = StringSplit(m_partial_tp_percentages, ',', percentages_str);
      if (m_partial_tp_stage_hit >= num_levels) return;

      double current_price_ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double current_price_bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      
      for(int i = m_partial_tp_stage_hit; i < num_levels && i < 3; i++)
      {
         if(m_tp_levels_price[i] == 0.0) continue;
         
         bool target_hit = (pos_type == POSITION_TYPE_BUY && current_price_bid >= m_tp_levels_price[i]) ||
                           (pos_type == POSITION_TYPE_SELL && current_price_ask <= m_tp_levels_price[i]);

         if(target_hit)
         {
            double volume_to_close = NormalizeDouble(m_initial_volume * (StringToDouble(percentages_str[i]) / 100.0), 2);
            double remaining_volume = PositionGetDouble(POSITION_VOLUME);
            
            // اگر این آخرین پله نباشد و حجم درخواستی بیشتر از حجم باقیمانده باشد، کمی فضا برای ادامه معامله بگذار
            if(volume_to_close >= remaining_volume && i < num_levels - 1)
               volume_to_close = NormalizeDouble(remaining_volume - SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN), 2);
            
            if(volume_to_close < SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN)) continue;

            if(m_trade.PositionClosePartial(m_position_ticket, volume_to_close))
            {
               Log("خروج پله‌ای " + (string)(i+1) + " انجام شد: " + DoubleToString(volume_to_close, 2) + " لات.");
               m_partial_tp_stage_hit = i + 1;
               UpdateTPVisuals(m_partial_tp_stage_hit);
            }
         }
      }
   }

   void CreateTPVisuals()
   {
      ClearTPVisuals();
      for(int i=0; i<3; i++)
      {
         if(m_tp_levels_price[i] == 0.0) continue;
         string name = "TP_Level_" + (string)m_magic_number + "_" + IntegerToString(i+1);
         if(ObjectCreate(0, name, OBJ_TEXT, 0, TimeCurrent() + (PeriodSeconds() * (10 + i*5)), m_tp_levels_price[i]))
         {
            ObjectSetString(0, name, OBJPROP_TEXT, "T" + IntegerToString(i+1));
            ObjectSetInteger(0, name, OBJPROP_COLOR, clrOrange);
            ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 8);
            ObjectSetString(0, name, OBJPROP_FONT, "Wingdings");
            ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LEFT);
         }
      }
   }
   
   void UpdateTPVisuals(int stage_hit)
   {
      for(int i=0; i < stage_hit; i++)
      {
         string name = "TP_Level_" + (string)m_magic_number + "_" + IntegerToString(i+1);
         ObjectSetInteger(0, name, OBJPROP_COLOR, clrLimeGreen);
      }
   }

   void ClearTPVisuals()
   {
      for(int i=1; i<=3; i++) 
         ObjectDelete(0, "TP_Level_" + (string)m_magic_number + "_" + IntegerToString(i));
   }

public:
   //+------------------------------------------------------------------+
   //| سازنده کلاس (Constructor) بازنویسی شده                         |
   //+------------------------------------------------------------------+
   CHipoFino(ENUM_TIMEFRAMES htf, ENUM_TIMEFRAMES ltf, int htf_fast_ema, int htf_slow_ema, int htf_signal,
             int ltf_fast_ema, int ltf_slow_ema, int ltf_signal, double risk_percent,
             long magic_number,
             bool use_session_filter, bool tokyo, bool london, bool newyork, string custom_start, string custom_end,
             // پارامترهای جدید
             bool use_partial_tp, string partial_tp_percentages, double fixed_tp_rr,
             bool use_trailing_stop, double trailing_activation_rr,
             // پارامترهای تریلینگ
             ENUM_STOP_METHOD stop_method, double sar_step, double sar_max, 
             int min_lookback, int max_lookback, int fractal_bars, int fractal_buffer_pips,
             bool show_stop_line, bool show_fractals,
             ENUM_INITIAL_STOP_METHOD initial_stop_method, int initial_sl_buffer_pips, // 👈 بافر پیپ جدید
             ENUM_TIMEFRAMES atr_ma_timeframe, ENUM_MA_METHOD ma_method, int ma_period, ENUM_APPLIED_PRICE ma_price,
             int atr_period, double atr_multiplier,
             ENUM_TIMEFRAMES simple_fractal_timeframe, int simple_fractal_bars, int simple_fractal_peers, double simple_fractal_buffer_pips)
   {
      m_htf = htf;
      m_ltf = ltf;
      m_htf_fast_ema = htf_fast_ema;
      m_htf_slow_ema = htf_slow_ema;
      m_htf_signal = htf_signal;
      m_ltf_fast_ema = ltf_fast_ema;
      m_ltf_slow_ema = ltf_slow_ema;
      m_ltf_signal = ltf_signal;
      m_risk_percent = risk_percent;
     // m_sl_buffer_pips = sl_buffer_pips;
      m_magic_number = magic_number;
      
      m_use_session_filter = use_session_filter;
      m_tokyo_session = tokyo;
      m_london_session = london;
      m_newyork_session = newyork;
      m_custom_session_start = custom_start;
      m_custom_session_end = custom_end;
      
      m_use_partial_tp = use_partial_tp;
      m_partial_tp_percentages = partial_tp_percentages;
      m_fixed_tp_rr = fixed_tp_rr;
      m_use_trailing_stop = use_trailing_stop;
      m_trailing_activation_rr = trailing_activation_rr;
      
      m_stop_method = stop_method;
      m_sar_step = sar_step;
      m_sar_maximum = sar_max;
      m_min_lookback = min_lookback;
      m_max_lookback = max_lookback;
      m_fractal_bars = fractal_bars;
      m_fractal_buffer_pips = fractal_buffer_pips;
      m_show_stop_line = show_stop_line;
      m_show_fractals = show_fractals;
      m_initial_sl_manager = new CHipoInitialStopLoss(
               initial_stop_method, initial_sl_buffer_pips,
               atr_ma_timeframe, ma_method, ma_period, ma_price, atr_period, atr_multiplier,
               simple_fractal_timeframe, simple_fractal_bars, simple_fractal_peers, simple_fractal_buffer_pips
            );
      m_htf_macd_handle = INVALID_HANDLE;
      m_ltf_macd_handle = INVALID_HANDLE;
      m_candle_times.htf_last_candle = 0;
      m_candle_times.ltf_last_candle = 0;
      m_log_buffer = "";
      m_last_flush_time = 0;
      m_state = HIPO_IDLE;
      m_position_ticket = 0;
      m_active_direction = LONG;
      m_fractals = NULL;
      m_trailing = NULL;
      
      ResetTradeManagementState();
      m_trade.SetExpertMagicNumber(m_magic_number);
   }
   
   //+------------------------------------------------------------------+
   //| تابع راه‌اندازی                                                |
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
      
      m_fractals = new CHipoMomentumFractals(m_ltf, m_fractal_bars, m_show_fractals);
      if(m_fractals == NULL || !m_fractals.Initialize())
      {
         Log("خطا: راه‌اندازی فراکتال‌یاب ناموفق بود");
         return false;
      }
      
      m_trailing = new CHipoCvtChannel(m_stop_method, m_sar_step, m_sar_maximum, m_min_lookback,
                                       m_max_lookback, m_fractal_buffer_pips, m_show_stop_line, m_fractals);
      if(m_trailing == NULL || !m_trailing.Initialize())
      {
         Log("خطا: راه‌اندازی تریلینگ استاپ ناموفق بود");
         delete m_fractals;
         return false;
      }
      
      if(m_initial_sl_manager == NULL || !m_initial_sl_manager.Initialize())
      {
         Log("خطا: راه‌اندازی مدیریت استاپ لاس اولیه ناموفق بود");
         if(m_trailing != NULL) m_trailing.Deinitialize(); delete m_trailing;
         if(m_fractals != NULL) m_fractals.Deinitialize(); delete m_fractals;
         return false;
      }
      
      m_candle_times.htf_last_candle = iTime(_Symbol, m_htf, 0);
      m_candle_times.ltf_last_candle = iTime(_Symbol, m_ltf, 0);
      Log("موتور اصلی با موفقیت راه‌اندازی شد");
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| تابع توقف                                                      |
   //+------------------------------------------------------------------+
   void Deinitialize()
   {
     if(m_initial_sl_manager != NULL)
      {
         m_initial_sl_manager.Deinitialize();
         delete m_initial_sl_manager;
         m_initial_sl_manager = NULL;
      }
   
      if(m_trailing != NULL)
      {
         m_trailing.Deinitialize();
         delete m_trailing;
         m_trailing = NULL; // 👈 این خط رو هم اضافه کن
      }
      if(m_fractals != NULL)
      {
         m_fractals.Deinitialize();
         delete m_fractals;
         m_fractals = NULL; // 👈 این خط رو هم اضافه کن
      }
      if(m_htf_macd_handle != INVALID_HANDLE)
         IndicatorRelease(m_htf_macd_handle);
      if(m_ltf_macd_handle != INVALID_HANDLE)
         IndicatorRelease(m_ltf_macd_handle);
      FlushLog();
      Log("موتور اصلی متوقف شد");
   }
   //+------------------------------------------------------------------+
   //| تابع ارسال معامله (SendTrade) بازنویسی شده                    |
   //+------------------------------------------------------------------+
 bool SendTrade(SSignal &signal, double entry_price, double initial_mother_zero) // 👈 mother_zero به عنوان ورودی
{
   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   request.action = TRADE_ACTION_DEAL;
   request.symbol = _Symbol;
   request.type = (signal.type == "Buy") ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   request.price = entry_price;
   request.magic = m_magic_number;

   // 👈 محاسبه استاپ لاس نهایی با استفاده از کلاس جدید
   // sl_price رو از اینجا حذف کردم چون از GetFinalStopLoss میگیریم
 ENUM_DIRECTION trade_direction_for_sl = (request.type == ORDER_TYPE_BUY) ? LONG : SHORT;
   double calculated_sl_price = m_initial_sl_manager.GetFinalStopLoss(trade_direction_for_sl, entry_price, initial_mother_zero);
   if (calculated_sl_price == 0.0) // 👈 اگر محاسبه SL موفق نبود
   {
      Log("خطا: استاپ لاس اولیه محاسبه نشد. معامله ارسال نمیگردد.");
      return false;
   }

   request.sl = calculated_sl_price; // 👈 SL نهایی

   // حجم معامله بر اساس SL نهایی محاسبه میشه
   request.volume = CalculateVolume(entry_price, calculated_sl_price);

   // اگر حجم معتبر نبود، ارسال معامله متوقف میشود
   if (request.volume <= 0 || request.volume < SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN))
   {
       Log("خطا: حجم معامله نامعتبر است: " + DoubleToString(request.volume, 2));
       return false;
   }

   if(!m_use_partial_tp)
   {
      double risk_pips = MathAbs(entry_price - calculated_sl_price) / _Point;
      if(request.type == ORDER_TYPE_BUY)
         request.tp = entry_price + (risk_pips * m_fixed_tp_rr * _Point);
      else
         request.tp = entry_price - (risk_pips * m_fixed_tp_rr * _Point);
   }
   else
   {
      request.tp = 0; // برای Partial TP، Take Profit اولیه رو صفر میذاریم
   }

   if(!m_trade.OrderSend(request, result))
   {
      Log("خطا در ارسال معامله: " + (string)GetLastError() + ", comment: " + result.comment);
      return false;
   }

   m_position_ticket = result.order;
   Log("معامله باز شد: تیکت=" + (string)m_position_ticket);

   if(!PositionSelectByTicket(m_position_ticket))
   {
      Log("خطا: پوزیشن باز شده بلافاصله یافت نشد.");
      return false;
   }

   ResetTradeManagementState();
   m_entry_price = PositionGetDouble(POSITION_PRICE_OPEN);
   m_initial_sl_price = calculated_sl_price; // 👈 SL اولیه ثبت میشه
   m_initial_volume = PositionGetDouble(POSITION_VOLUME);
   m_initial_risk_pips = MathAbs(m_entry_price - m_initial_sl_price) / _Point;

   CalculateAndDrawTPs();

   return true;
}

   //+------------------------------------------------------------------+
   //| تابع پردازش تیک (OnTick) بازنویسی شده                          |
   //+------------------------------------------------------------------+
   void OnTick()
   {
      if(TimeCurrent() - m_last_flush_time >= 5) FlushLog();
      
      bool new_ltf_candle = IsNewCandle(m_ltf, m_candle_times.ltf_last_candle);
      if(IsNewCandle(m_htf, m_candle_times.htf_last_candle) || new_ltf_candle)
      {
         HFiboOnNewBar();
     
     if(m_fractals != NULL) m_fractals.Calculate();

      }
      
      ENUM_MACD_BIAS htf_bias = GetMacdBias(m_htf_macd_handle, m_htf);
      ENUM_MACD_BIAS ltf_bias = GetMacdBias(m_ltf_macd_handle, m_ltf);
      if(g_dashboard != NULL) g_dashboard.UpdateMacdBias(htf_bias, ltf_bias, m_state);
      
      switch(m_state)
      {
         case HIPO_IDLE:
         {
            if(!IsSessionActive()) return;
            if((htf_bias == MACD_BULLISH && ltf_bias == MACD_BULLISH) ||
               (htf_bias == MACD_BEARISH && ltf_bias == MACD_BEARISH))
            {
               // دستور جدید: پاکسازی چارت قبل از تحلیل جدید
               HFiboStopCurrentStructure(); 
               
               ENUM_DIRECTION direction = (htf_bias == MACD_BULLISH) ? LONG : SHORT;
               if(HFiboCreateNewStructure(direction))
               {
                  m_active_direction = direction;
                  m_state = HIPO_WAITING_FOR_HIPO;
                  Log("دستور ایجاد ساختار جدید ارسال شد: " + (direction == LONG ? "خرید" : "فروش"));
               }
            }
            break;
         }
         
         case HIPO_WAITING_FOR_HIPO:
         {
            if((m_active_direction == LONG && htf_bias == MACD_BEARISH) ||
               (m_active_direction == SHORT && htf_bias == MACD_BULLISH))
            {
               HFiboStopCurrentStructure();
               m_state = HIPO_IDLE;
               Log("روند HTF معکوس شد، ساختار متوقف شد");
            }
            else if(HFiboIsStructureBroken())
            {
               HFiboStopCurrentStructure();
               m_state = HIPO_IDLE;
               Log("ساختار فیبوناچی تخریب شد، بازگشت به حالت بیکار");
            }
            else
            {
               SSignal signal = HFiboGetSignal();
              // Log("وضعیت سیگنال دریافتی: ID=" + signal.id + ", Type=" + signal.type); // 👈 این لاگ رو اضافه کن برای دیباگ
               if(signal.id != "")
               {
                   double mother_zero = HFiboGetMotherZeroPoint(); // 👈 صفر مادر رو از HFibo میگیریم
                   double entry_price = (signal.type == "Buy") ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
      
                    if(SendTrade(signal, entry_price, mother_zero)) // 👈 حالا mother_zero رو پاس میدیم به SendTrade
                    {
                       m_state = HIPO_MANAGING_POSITION;
                       Log("وارد حالت مدیریت معامله شد");
                       HFiboAcknowledgeSignal(signal.id); 
                    }
                  else
                  {
                     HFiboStopCurrentStructure();
                     m_state = HIPO_IDLE;
                     Log("خطا در ارسال معامله، بازگشت به حالت بیکار");
                  }
               }
            }
            break;
         }
         
         case HIPO_MANAGING_POSITION:
         {
            if(!PositionSelectByTicket(m_position_ticket))
            {
               HFiboAcknowledgeSignal("");
               if(m_trailing != NULL) m_trailing.UpdateVisuals(0.0, POSITION_TYPE_BUY);
               ResetTradeManagementState();
               m_state = HIPO_IDLE;
               Log("معامله بسته شد، بازگشت به حالت بیکار");
               break;
            }

            ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            double current_sl = PositionGetDouble(POSITION_SL);
            
            if(new_ltf_candle)
            {
               ManagePartialTPs();
            }
            
            if(m_use_trailing_stop)
            {
               // فاز ۱: فعال‌سازی
               if(!m_is_trailing_active)
               {
                  double current_price = (pos_type == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
                  double current_rr = 0;
                  if(m_initial_risk_pips > 0)
                  {
                     if(pos_type == POSITION_TYPE_BUY)
                        current_rr = (current_price - m_entry_price) / (m_initial_risk_pips * _Point);
                     else
                        current_rr = (m_entry_price - current_price) / (m_initial_risk_pips * _Point);
                  }
                  
                  if(current_rr >= m_trailing_activation_rr)
                  {
                     m_is_trailing_active = true;
                     Log("تریلینگ استاپ فعال شد.");
                  }
               }
               
               // فاز ۲: تریلینگ با قانون کف سیمانی
               if(m_is_trailing_active)
               {
                  double suggested_sl = m_trailing.CalculateNewStopLoss(pos_type, current_sl);
                  bool is_valid_sl = false;

                  if((pos_type == POSITION_TYPE_BUY && suggested_sl >= m_entry_price) ||
                     (pos_type == POSITION_TYPE_SELL && suggested_sl <= m_entry_price && suggested_sl > 0))
                  {
                     is_valid_sl = true;
                  }

                  if(is_valid_sl && suggested_sl != current_sl)
                  {
                     if(m_trade.PositionModify(m_position_ticket, suggested_sl, PositionGetDouble(POSITION_TP)))
                     {
                        Log("حد ضرر به‌روزرسانی شد: " + DoubleToString(suggested_sl, _Digits));
                     }
                  }
               }
            }
            if(m_trailing != NULL) m_trailing.UpdateVisuals(PositionGetDouble(POSITION_SL), pos_type);
            break;
         }
      }
   }
};

#endif
