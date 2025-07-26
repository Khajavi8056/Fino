//+------------------------------------------------------------------+
//|                                                    HipoFino.mqh  |
//|                              محصولی از: Hipo Algorithm           |
//|                              نسخه: ۱.۱.۰                          |
//|                              تاریخ: ۲۰۲۵/۰۷/۲۵                   |
//| موتور اصلی اکسپرت HipoFino برای مدیریت معاملات و مکدی‌ها       |
//+------------------------------------------------------------------+

#ifndef HIPO_FINO_MQH
#define HIPO_FINO_MQH

#include <Trade\Trade.mqh>
#include <HipoFibonacci.mqh>
#include "HipoDashboard.mqh"
#include "HipoMomentumFractals.mqh"
#include "HipoCvtChannel.mqh"

//+------------------------------------------------------------------+
//| ثابت‌ها و ساختارها                                                         |
//|     در سایر کتابخانه و فایل ها این ساختار ها وجود دارد                                       |
//+------------------------------------------------------------------+
/*/*enum ENUM_HIPO_STATE
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

enum ENUM_STOP_METHOD
{
   STOP_SAR,      // استفاده از Parabolic SAR
   STOP_CVT,      // استفاده از کانال دینامیک CVT
   STOP_FRACTAL   // استفاده از فراکتال مومنتوم
};*/
//در سایر کتابخانه و فایل ها این ساختار ها وجود دارد 
//+------------------------------------------------------------------+
//| ساختار برای ذخیره زمان کندل‌ها                                 |
//+------------------------------------------------------------------+
struct SCandleTime
{
   datetime htf_last_candle;  // زمان آخرین کندل HTF
   datetime ltf_last_candle;  // زمان آخرین کندل LTF
};

//+------------------------------------------------------------------+
//| کلاس CHipoFino: موتور اصلی اکسپرت                              |
//+------------------------------------------------------------------+
class CHipoFino
{
private:
   ENUM_TIMEFRAMES m_htf;         // تایم‌فریم روند
   ENUM_TIMEFRAMES m_ltf;         // تایم‌فریم تریگر
   int m_htf_fast_ema, m_htf_slow_ema, m_htf_signal;  // تنظیمات مکدی HTF
   int m_ltf_fast_ema, m_ltf_slow_ema, m_ltf_signal;  // تنظیمات مکدی LTF
   double m_risk_percent;         // درصد ریسک
   double m_risk_reward_ratio;    // نسبت ریسک به ریوارد
   int m_sl_buffer_pips;          // بافر حد ضرر
   long m_magic_number;           // شماره جادویی
   int m_htf_macd_handle;         // هندل مکدی HTF
   int m_ltf_macd_handle;         // هندل مکدی LTF
   SCandleTime m_candle_times;    // زمان آخرین کندل‌ها
   string m_log_buffer;           // بافر لاگ
   datetime m_last_flush_time;    // زمان آخرین فلاش لاگ
   ENUM_HIPO_STATE m_state;       // حالت فعلی اکسپرت
   ulong m_position_ticket;       // تیکت معامله باز (تغییر از long به ulong)
   ENUM_DIRECTION m_active_direction; // جهت فعال تحلیل
   // متغیرهای فیلتر سشن
   bool m_use_session_filter;     // استفاده از فیلتر سشن
   bool m_tokyo_session;         // سشن توکیو
   bool m_london_session;        // سشن لندن
   bool m_newyork_session;       // سشن نیویورک
   string m_custom_session_start; // شروع سشن سفارشی
   string m_custom_session_end;   // پایان سشن سفارشی
   // متغیرهای تریلینگ استاپ
   ENUM_STOP_METHOD m_stop_method; // روش تریلینگ استاپ
   double m_sar_step;             // گام SAR
   double m_sar_maximum;          // حداکثر SAR
   int m_min_lookback;            // حداقل دوره کانال CVT
   int m_max_lookback;            // حداکثر دوره کانال CVT
   int m_fractal_bars;            // تعداد کندل‌های فراکتال
   int m_fractal_buffer_pips;     // بافر فراکتال
   bool m_show_stop_line;         // نمایش خط استاپ
   bool m_show_fractals;          // نمایش فراکتال‌ها
   CHipoMomentumFractals* m_fractals; // نمونه فراکتال‌یاب
   CHipoCvtChannel* m_trailing;   // نمونه تریلینگ استاپ

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
   //| تابع ارسال معامله به بروکر                                     |
   //+------------------------------------------------------------------+
   bool SendTrade(SSignal &signal, double entry_price, double sl_price)
   {
      MqlTradeRequest request = {};
      MqlTradeResult result = {};
      request.action = TRADE_ACTION_DEAL; // مقدار صفر به مقدار صحیح تغییر کرد
      request.symbol = _Symbol;
      request.volume = CalculateVolume(entry_price, sl_price);
      request.type = (signal.type == "Buy") ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
      request.price = entry_price;
      request.sl = sl_price;
      request.tp = (signal.type == "Buy") ? entry_price + MathAbs(entry_price - sl_price) * m_risk_reward_ratio :
                                           entry_price - MathAbs(entry_price - sl_price) * m_risk_reward_ratio;
      request.magic = m_magic_number;
      
      if(!OrderSend(request, result) || result.retcode != TRADE_RETCODE_DONE)
      {
         Log("خطا در ارسال معامله: کد=" + IntegerToString(result.retcode) + ", پیام=" + result.comment);
         return false;
      }
      
      m_position_ticket = result.deal; // حالا نوع داده‌ها همخوانی دارد
      Log("معامله باز شد: تیکت=" + IntegerToString(m_position_ticket) + ", نوع=" + signal.type +
          ", حجم=" + DoubleToString(request.volume, 2) + ", ورود=" + DoubleToString(entry_price, _Digits) +
          ", حد ضرر=" + DoubleToString(sl_price, _Digits) + ", حد سود=" + DoubleToString(request.tp, _Digits));
      return true;
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
      
      // بازه‌های سشن به وقت GMT (دقیقه)
      int tokyo_start = 0;        // 00:00
      int tokyo_end = 9 * 60;     // 09:00
      int london_start = 8 * 60;  // 08:00
      int london_end = 17 * 60;   // 17:00
      int newyork_start = 13 * 60;// 13:00
      int newyork_end = 22 * 60;  // 22:00
      
      // سشن سفارشی
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

public:
   //+------------------------------------------------------------------+
   //| سازنده کلاس                                                   |
   //+------------------------------------------------------------------+
   CHipoFino(ENUM_TIMEFRAMES htf, ENUM_TIMEFRAMES ltf, int htf_fast_ema, int htf_slow_ema, int htf_signal,
             int ltf_fast_ema, int ltf_slow_ema, int ltf_signal, double risk_percent,
             double risk_reward_ratio, int sl_buffer_pips, long magic_number,
             bool use_session_filter, bool tokyo_session, bool london_session, bool newyork_session,
             string custom_session_start, string custom_session_end,
             ENUM_STOP_METHOD stop_method, double sar_step, double sar_maximum,
             int min_lookback, int max_lookback, int fractal_bars, int fractal_buffer_pips,
             bool show_stop_line, bool show_fractals)
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
      m_risk_reward_ratio = risk_reward_ratio;
      m_sl_buffer_pips = sl_buffer_pips;
      m_magic_number = magic_number;
      m_use_session_filter = use_session_filter;
      m_tokyo_session = tokyo_session;
      m_london_session = london_session;
      m_newyork_session = newyork_session;
      m_custom_session_start = custom_session_start;
      m_custom_session_end = custom_session_end;
      m_stop_method = stop_method;
      m_sar_step = sar_step;
      m_sar_maximum = sar_maximum;
      m_min_lookback = min_lookback;
      m_max_lookback = max_lookback;
      m_fractal_bars = fractal_bars;
      m_fractal_buffer_pips = fractal_buffer_pips;
      m_show_stop_line = show_stop_line;
      m_show_fractals = show_fractals;
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
   }
   
   //+------------------------------------------------------------------+
   //| تابع راه‌اندازی                                              |
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
      
      m_candle_times.htf_last_candle = iTime(_Symbol, m_htf, 0);
      m_candle_times.ltf_last_candle = iTime(_Symbol, m_ltf, 0);
      Log("موتور اصلی با موفقیت راه‌اندازی شد");
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| تابع توقف                                                    |
   //+------------------------------------------------------------------+
   void Deinitialize()
   {
      if(m_trailing != NULL)
      {
         m_trailing.Deinitialize();
         delete m_trailing;
      }
      if(m_fractals != NULL)
      {
         m_fractals.Deinitialize();
         delete m_fractals;
      }
      if(m_htf_macd_handle != INVALID_HANDLE)
         IndicatorRelease(m_htf_macd_handle);
      if(m_ltf_macd_handle != INVALID_HANDLE)
         IndicatorRelease(m_ltf_macd_handle);
      FlushLog();
      Log("موتور اصلی متوقف شد");
   }
   
   //+------------------------------------------------------------------+
   //| تابع پردازش تیک                                              |
   //+------------------------------------------------------------------+
void OnTick()
{
   // فلاش لاگ هر ۵ ثانیه
   if(TimeCurrent() - m_last_flush_time >= 5)
      FlushLog();
   
   // بررسی کندل جدید
   bool new_htf_candle = IsNewCandle(m_htf, m_candle_times.htf_last_candle);
   bool new_ltf_candle = IsNewCandle(m_ltf, m_candle_times.ltf_last_candle);
   if(new_htf_candle || new_ltf_candle)
   {
      HFiboOnNewBar();
      m_fractals.CalculateFractals();
   }
   
   // دریافت بایاس مکدی
   ENUM_MACD_BIAS htf_bias = GetMacdBias(m_htf_macd_handle, m_htf);
   ENUM_MACD_BIAS ltf_bias = GetMacdBias(m_ltf_macd_handle, m_ltf);
   
   // به‌روزرسانی داشبورد
   if(g_dashboard != NULL)
      g_dashboard.UpdateMacdBias(htf_bias, ltf_bias, m_state);
   
   // مدیریت حالت‌ها
   switch(m_state)
   {
      case HIPO_IDLE:
         if(!IsSessionActive()) return;
         if((htf_bias == MACD_BULLISH && ltf_bias == MACD_BULLISH) ||
            (htf_bias == MACD_BEARISH && ltf_bias == MACD_BEARISH))
         {
            ENUM_DIRECTION direction = (htf_bias == MACD_BULLISH) ? LONG : SHORT;
            if(HFiboCreateNewStructure(direction))
            {
               m_active_direction = direction;
               m_state = HIPO_WAITING_FOR_HIPO;
               Log("دستور ایجاد ساختار جدید ارسال شد: جهت=" + (direction == LONG ? "خرید" : "فروش"));
            }
            else
            {
               Log("خطا در ایجاد ساختار جدید");
            }
         }
         break;
         
      case HIPO_WAITING_FOR_HIPO:
         if((m_active_direction == LONG && htf_bias == MACD_BEARISH) ||
            (m_active_direction == SHORT && htf_bias == MACD_BULLISH))
         {
            HFiboStopCurrentStructure();
            m_state = HIPO_IDLE;
            Log("روند HTF کاملاً معکوس شد، ساختار متوقف شد");
         }
         else if(HFiboIsStructureBroken())
         {
            HFiboStopCurrentStructure();
            m_state = HIPO_IDLE;
            Log("ساختار به دلیل عبور از سطح شکست تخریب شد، بازگشت به حالت بیکار");
         }
         else
         {
            SSignal signal = HFiboGetSignal();
            if(signal.id != "")
            {
               double mother_zero = HFiboGetMotherZeroPoint();
               double entry_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
               double sl_price = (signal.type == "Buy") ? mother_zero - m_sl_buffer_pips * _Point :
                                                        mother_zero + m_sl_buffer_pips * _Point;
               if(SendTrade(signal, entry_price, sl_price))
               {
                  m_state = HIPO_MANAGING_POSITION;
                  Log("وارد حالت مدیریت معامله شد");
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
         
      case HIPO_MANAGING_POSITION:
         if(!PositionSelectByTicket(m_position_ticket))
         {
            HFiboAcknowledgeSignal("");
            m_trailing.UpdateVisuals(0.0, POSITION_TYPE_BUY);
            m_state = HIPO_IDLE;
            Log("معامله بسته شد (حد سود یا ضرر)، بازگشت به حالت بیکار");
         }
         else
         {
            ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            double current_sl = PositionGetDouble(POSITION_SL);
            double new_sl = m_trailing.CalculateNewStopLoss(pos_type, current_sl);
            if((pos_type == POSITION_TYPE_BUY && new_sl > current_sl) ||
               (pos_type == POSITION_TYPE_SELL && new_sl < current_sl && new_sl > 0))
            {
               MqlTradeRequest request = {};
               MqlTradeResult result = {};
               request.action = TRADE_ACTION_SLTP;
               request.position = m_position_ticket;
               request.symbol = _Symbol;
               request.sl = new_sl;
               request.tp = PositionGetDouble(POSITION_TP);
               if(OrderSend(request, result) && result.retcode == TRADE_RETCODE_DONE)
               {
                  Log("حد ضرر به‌روزرسانی شد: تیکت=" + IntegerToString(m_position_ticket) +
                      ", حد ضرر جدید=" + DoubleToString(new_sl, _Digits));
               }
               else
               {
                  Log("خطا در به‌روزرسانی حد ضرر: کد=" + IntegerToString(result.retcode));
               }
            }
            m_trailing.UpdateVisuals(new_sl, pos_type);
         }
         break;
   }
}
};
#endif
