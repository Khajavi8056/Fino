//+------------------------------------------------------------------+
//|                                             HipoCvtChannel.mqh   |
//|                              محصولی از: Hipo Algorithm           |
//|                              نسخه: ۲.۰.۰ (ارتقا یافته)            |
//|                              تاریخ: ۲۰۲۵/۰۷/۲۸                   |
//|      کتابخانه مدیریت حد ضرر متحرک با روش‌های جدید                |
//+------------------------------------------------------------------+

#ifndef HIPO_CVT_CHANNEL_MQH
#define HIPO_CVT_CHANNEL_MQH

#include <Trade\Trade.mqh>
#include "HipoFino.mqh"
#include "HipoMomentumFractals.mqh"
#include <Indicators\Indicators.mqh>

//+------------------------------------------------------------------+
//| ENUM روش‌های تریلینگ استاپ (ارتقا یافته)
//+------------------------------------------------------------------+
enum ENUM_STOP_METHOD
{
   STOP_SAR,                  // استفاده از Parabolic SAR
   STOP_CVT,                  // استفاده از کانال دینامیک CVT
   STOP_FRACTAL,              // استفاده از فراکتال مومنتوم
   STOP_ATR_MA,               // <<-- جدید: روش ترکیب ATR و میانگین متحرک
   STOP_SIMPLE_FRACTAL        // <<-- جدید: روش فراکتال ساده
};

//+------------------------------------------------------------------+
//| کلاس CHipoCvtChannel (ارتقا یافته)
//+------------------------------------------------------------------+
class CHipoCvtChannel
{
private:
   // --- تنظیمات عمومی و روش‌های قدیمی ---
   ENUM_STOP_METHOD m_stop_method;
   bool   m_show_stop_line;
   CHipoMomentumFractals* m_fractals;
   
   // --- تنظیمات روش SAR و CVT ---
   double m_sar_step;
   double m_sar_maximum;
   int    m_min_lookback;
   int    m_max_lookback;
   
   // --- تنظیمات روش فراکتال مومنتوم ---
   int    m_fractal_buffer_pips;
   
   // --- تنظیمات روش ATR و MA (جدید) ---
   ENUM_TIMEFRAMES m_atr_ma_timeframe;
   ENUM_MA_METHOD  m_ma_method;
   int             m_ma_period;
   ENUM_APPLIED_PRICE m_ma_price;
   int             m_atr_period;
   double          m_atr_multiplier;
   
   // --- تنظیمات روش فراکتال ساده (جدید) ---
   ENUM_TIMEFRAMES m_simple_fractal_timeframe;
   int             m_simple_fractal_bars;
   int             m_simple_fractal_peers;
   double          m_simple_fractal_buffer_pips;

   // --- هندل اندیکاتورها (مخفی) ---
   int    m_sar_handle;
   int    m_atr_handle_for_cvt;
   int    m_ma_handle_for_atr_ts;
   int    m_atr_handle_for_atr_ts;

   // --- لاگ‌گیری ---
   string   m_log_buffer;
   datetime m_last_flush_time;

   //+------------------------------------------------------------------+
   //| توابع داخلی (کپی شده از HipoInitialStopLoss)
   //+------------------------------------------------------------------+
   double CalculateATRMAStopLoss(ENUM_DIRECTION trade_direction);
   double CalculateSimpleFractalStopLoss(ENUM_DIRECTION trade_direction);

   //+------------------------------------------------------------------+
   //| تابع لاگ‌گیری
   //+------------------------------------------------------------------+
   void Log(string message)
   {
      string log_entry = TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES|TIME_SECONDS) + ": [TrailingSL] " + message + "\n";
      m_log_buffer += log_entry;
      Print(log_entry);
   }
   
   //+------------------------------------------------------------------+
   //| تابع محاسبه دوره دینامیک CVT
   //+------------------------------------------------------------------+
   int CalculateDynamicPeriod(double close_price)
   {
      double sar[];
      if(CopyBuffer(m_sar_handle, 0, 1, 1, sar) <= 0) return m_min_lookback;
      double atr[];
      if(CopyBuffer(m_atr_handle_for_cvt, 0, 1, 1, atr) <= 0) return m_min_lookback;
      
      double speed = (atr[0] > 0) ? MathAbs(close_price - sar[0]) / atr[0] : 0;
      const double max_speed = 5.0;
      int period = m_min_lookback + (int)((m_max_lookback - m_min_lookback) * MathMin(speed / max_speed, 1.0));
      return MathMax(m_min_lookback, MathMin(m_max_lookback, period));
   }

public:
   //+------------------------------------------------------------------+
   //| سازنده کلاس (ارتقا یافته)
   //+------------------------------------------------------------------+
   CHipoCvtChannel(ENUM_STOP_METHOD stop_method, bool show_stop_line, CHipoMomentumFractals* fractals,
                   // پارامترهای SAR و CVT
                   double sar_step, double sar_maximum, int min_lookback, int max_lookback,
                   // پارامترهای فراکتال مومنتوم
                   int fractal_buffer_pips,
                   // پارامترهای ATR/MA
                   ENUM_TIMEFRAMES atr_ma_timeframe, ENUM_MA_METHOD ma_method, int ma_period, ENUM_APPLIED_PRICE ma_price,
                   int atr_period, double atr_multiplier,
                   // پارامترهای فراکتال ساده
                   ENUM_TIMEFRAMES simple_fractal_timeframe, int simple_fractal_bars, int simple_fractal_peers, double simple_fractal_buffer_pips)
   {
      // مقداردهی متغیرهای عمومی
      m_stop_method = stop_method;
      m_show_stop_line = show_stop_line;
      m_fractals = fractals;
      
      // مقداردهی متغیرهای SAR و CVT
      m_sar_step = sar_step;
      m_sar_maximum = sar_maximum;
      m_min_lookback = min_lookback;
      m_max_lookback = max_lookback;
      
      // مقداردهی متغیرهای فراکتال مومنتوم
      m_fractal_buffer_pips = fractal_buffer_pips;
      
      // مقداردهی متغیرهای ATR/MA
      m_atr_ma_timeframe = atr_ma_timeframe;
      m_ma_method = ma_method;
      m_ma_period = ma_period;
      m_ma_price = ma_price;
      m_atr_period = atr_period;
      m_atr_multiplier = atr_multiplier;
      
      // مقداردهی متغیرهای فراکتال ساده
      m_simple_fractal_timeframe = simple_fractal_timeframe;
      m_simple_fractal_bars = simple_fractal_bars;
      m_simple_fractal_peers = simple_fractal_peers;
      m_simple_fractal_buffer_pips = simple_fractal_buffer_pips;

      // ریست کردن هندل ها
      m_sar_handle = INVALID_HANDLE;
      m_atr_handle_for_cvt = INVALID_HANDLE;
      m_ma_handle_for_atr_ts = INVALID_HANDLE;
      m_atr_handle_for_atr_ts = INVALID_HANDLE;
   }
   
   //+------------------------------------------------------------------+
   //| تابع راه‌اندازی (ارتقا یافته)
   //+------------------------------------------------------------------+
   bool Initialize()
   {
      // ساخت هندل ها فقط در صورت نیاز (برای مخفی ماندن از چارت)
      if(m_stop_method == STOP_SAR || m_stop_method == STOP_CVT)
      {
         m_sar_handle = iSAR(_Symbol, PERIOD_CURRENT, m_sar_step, m_sar_maximum);
         if(m_sar_handle == INVALID_HANDLE) { Log("خطا: ایجاد هندل SAR ناموفق بود"); return false; }
      }
      if(m_stop_method == STOP_CVT)
      {
         m_atr_handle_for_cvt = iATR(_Symbol, PERIOD_CURRENT, 14);
         if(m_atr_handle_for_cvt == INVALID_HANDLE) { Log("خطا: ایجاد هندل ATR برای CVT ناموفق بود"); return false; }
      }
      if(m_stop_method == STOP_ATR_MA)
      {
         m_ma_handle_for_atr_ts = iMA(_Symbol, m_atr_ma_timeframe, m_ma_period, 0, m_ma_method, m_ma_price);
         m_atr_handle_for_atr_ts = iATR(_Symbol, m_atr_ma_timeframe, m_atr_period);
         if(m_ma_handle_for_atr_ts == INVALID_HANDLE || m_atr_handle_for_atr_ts == INVALID_HANDLE)
         {
            Log("خطا: ایجاد هندل MA یا ATR برای تریلینگ استاپ ناموفق بود.");
            return false;
         }
      }
      Log("تریلینگ استاپ با موفقیت راه‌اندازی شد. روش انتخابی: " + EnumToString(m_stop_method));
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| تابع توقف (ارتقا یافته)
   //+------------------------------------------------------------------+
   void Deinitialize()
   {
      if(m_sar_handle != INVALID_HANDLE) IndicatorRelease(m_sar_handle);
      if(m_atr_handle_for_cvt != INVALID_HANDLE) IndicatorRelease(m_atr_handle_for_cvt);
      if(m_ma_handle_for_atr_ts != INVALID_HANDLE) IndicatorRelease(m_ma_handle_for_atr_ts);
      if(m_atr_handle_for_atr_ts != INVALID_HANDLE) IndicatorRelease(m_atr_handle_for_atr_ts);
      
      if(m_show_stop_line) ObjectDelete(0, "HipoStopLine");
      Log("تریلینگ استاپ متوقف شد");
   }
   
   //+------------------------------------------------------------------+
   //| تابع محاسبه حد ضرر جدید (ارتقا یافته)
   //+------------------------------------------------------------------+
   double CalculateNewStopLoss(ENUM_POSITION_TYPE pos_type, double current_sl)
   {
      double new_sl = 0.0;
      ENUM_DIRECTION direction = (pos_type == POSITION_TYPE_BUY) ? LONG : SHORT;

      switch(m_stop_method)
      {
         case STOP_SAR:
         {
            double sar[];
            if(CopyBuffer(m_sar_handle, 0, 1, 1, sar) > 0) new_sl = sar[0];
            break;
         }
         case STOP_CVT:
         {
            double close[];
            if(CopyClose(_Symbol, PERIOD_CURRENT, 1, 1, close) <= 0) break;
            int period = CalculateDynamicPeriod(close[0]);
            double high[], low[];
            if(CopyHigh(_Symbol, PERIOD_CURRENT, 1, period, high) > 0 && CopyLow(_Symbol, PERIOD_CURRENT, 1, period, low) > 0)
            {
               new_sl = (direction == LONG) ? low[ArrayMinimum(low)] : high[ArrayMaximum(high)];
            }
            break;
         }
         case STOP_FRACTAL:
         {
            for(int i = 0; i < ArraySize(m_fractals.MajorHighs); i++)
            {
               if(direction == LONG && m_fractals.MajorLows[i] != EMPTY_VALUE)
               {
                  new_sl = m_fractals.MajorLows[i] - m_fractal_buffer_pips * _Point;
                  break;
               }
               else if(direction == SHORT && m_fractals.MajorHighs[i] != EMPTY_VALUE)
               {
                  new_sl = m_fractals.MajorHighs[i] + m_fractal_buffer_pips * _Point;
                  break;
               }
            }
            break;
         }
         case STOP_ATR_MA:
         {
            new_sl = CalculateATRMAStopLoss(direction);
            break;
         }
         case STOP_SIMPLE_FRACTAL:
         {
            new_sl = CalculateSimpleFractalStopLoss(direction);
            break;
         }
      }

      // قانون کف سیمانی: استاپ جدید فقط در صورتی معتبر است که سود را قفل کند
      if(new_sl == 0.0) return current_sl;
      if((direction == LONG && new_sl <= current_sl) || (direction == SHORT && new_sl >= current_sl))
      {
         return current_sl;
      }
      
      return new_sl;
   }
   
   //+------------------------------------------------------------------+
   //| تابع به‌روزرسانی نمایش خط استاپ
   //+------------------------------------------------------------------+
   void UpdateVisuals(double stop_price, ENUM_POSITION_TYPE pos_type)
   {
      if(!m_show_stop_line || stop_price == 0.0)
      {
         ObjectDelete(0, "HipoStopLine");
         return;
      }
      if(ObjectFind(0, "HipoStopLine") < 0)
      {
         if(!ObjectCreate(0, "HipoStopLine", OBJ_HLINE, 0, 0, stop_price)) return;
      }
      else
      {
         ObjectMove(0, "HipoStopLine", 0, 0, stop_price);
      }
      ObjectSetInteger(0, "HipoStopLine", OBJPROP_COLOR, pos_type == POSITION_TYPE_BUY ? clrGreen : clrRed);
      ObjectSetInteger(0, "HipoStopLine", OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, "HipoStopLine", OBJPROP_ZORDER, 1);
   }
};

//+------------------------------------------------------------------+
//| تابع محاسبه استاپ لاس با روش ATR و میانگین متحرک (برای تریلینگ)
//+------------------------------------------------------------------+
double CHipoCvtChannel::CalculateATRMAStopLoss(ENUM_DIRECTION trade_direction)
{
   double ma_value[];
   double atr_value[];
   if(CopyBuffer(m_ma_handle_for_atr_ts, 0, 0, 1, ma_value) < 1 || 
      CopyBuffer(m_atr_handle_for_atr_ts, 0, 0, 1, atr_value) < 1)
   {
      Log("خطا در دریافت داده های MA یا ATR برای تریلینگ استاپ.");
      return 0.0;
   }
   
   if (atr_value[0] == 0) return 0.0;

   if (trade_direction == LONG)
      return NormalizeDouble(ma_value[0] - (m_atr_multiplier * atr_value[0]), _Digits);
   else
      return NormalizeDouble(ma_value[0] + (m_atr_multiplier * atr_value[0]), _Digits);
}

//+------------------------------------------------------------------+
//| تابع محاسبه استاپ لاس با روش فراکتال ساده (برای تریلینگ)
//+------------------------------------------------------------------+
double CHipoCvtChannel::CalculateSimpleFractalStopLoss(ENUM_DIRECTION trade_direction)
{
   double fractal_price = 0.0;
   int total_bars = Bars(_Symbol, m_simple_fractal_timeframe);
   if (total_bars < m_simple_fractal_bars + m_simple_fractal_peers * 2 + 1) return 0.0;
   
   for (int i = 1; i < m_simple_fractal_bars; i++) 
   {
      if (trade_direction == LONG)
      {
         double current_low = iLow(_Symbol, m_simple_fractal_timeframe, i);
         bool is_fractal_low = true;
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
            break;
         }
      }
      else
      {
         double current_high = iHigh(_Symbol, m_simple_fractal_timeframe, i);
         bool is_fractal_high = true;
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
            break;
         }
      }
   }

   if (fractal_price == 0.0) return 0.0; 

   if (trade_direction == LONG)
      return NormalizeDouble(fractal_price - m_simple_fractal_buffer_pips * _Point, _Digits);
   else
      return NormalizeDouble(fractal_price + m_simple_fractal_buffer_pips * _Point, _Digits);
}

#endif
