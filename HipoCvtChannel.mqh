//+------------------------------------------------------------------+
//|                                             HipoCvtChannel.mqh   |
//|                              محصولی از: Hipo Algorithm           |
//|                              نسخه: ۱.۱.۰                          |
//|                              تاریخ: ۲۰۲۵/۰۷/۲۵                   |
//| کتابخانه مدیریت حد ضرر متحرک                                  |
//+------------------------------------------------------------------+

#ifndef HIPO_CVT_CHANNEL_MQH
#define HIPO_CVT_CHANNEL_MQH

#include "HipoMomentumFractals.mqh"

//+------------------------------------------------------------------+
//| کلاس CHipoCvtChannel                                            |
//+------------------------------------------------------------------+
class CHipoCvtChannel
{
private:
   ENUM_STOP_METHOD m_stop_method;    // روش تریلینگ استاپ
   double m_sar_step;                 // گام SAR
   double m_sar_maximum;              // حداکثر SAR
   int m_min_lookback;                // حداقل دوره کانال CVT
   int m_max_lookback;                // حداکثر دوره کانال CVT
   int m_fractal_buffer_pips;         // بافر فراکتال
   bool m_show_stop_line;             // نمایش خط استاپ
   CHipoMomentumFractals* m_fractals; // نمونه فراکتال‌یاب
   int m_sar_handle;                  // هندل SAR
   int m_atr_handle;                  // هندل ATR
   string m_log_buffer;               // بافر لاگ
   datetime m_last_flush_time;        // زمان آخرین فلاش لاگ

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
      int handle = FileOpen("HipoCvtChannel_Log.txt", FILE_WRITE|FILE_TXT|FILE_COMMON);
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
   //| تابع محاسبه دوره دینامیک CVT                                  |
   //+------------------------------------------------------------------+
   int CalculateDynamicPeriod(double close_price)
   {
      double sar[];
      ArraySetAsSeries(sar, true);
      if(CopyBuffer(m_sar_handle, 0, 1, 1, sar) <= 0)
      {
         Log("خطا در دریافت داده‌های SAR");
         return m_min_lookback;
      }
      double atr[];
      ArraySetAsSeries(atr, true);
      if(CopyBuffer(m_atr_handle, 0, 1, 1, atr) <= 0)
      {
         Log("خطا در دریافت داده‌های ATR");
         return m_min_lookback;
      }
      double speed = MathAbs(close_price - sar[0]) / atr[0];
      const double max_speed = 5.0;
      int period = m_min_lookback + (int)((m_max_lookback - m_min_lookback) * MathMin(speed / max_speed, 1.0));
      return MathMax(m_min_lookback, MathMin(m_max_lookback, period));
   }

public:
   //+------------------------------------------------------------------+
   //| سازنده کلاس                                                   |
   //+------------------------------------------------------------------+
   CHipoCvtChannel(ENUM_STOP_METHOD stop_method, double sar_step, double sar_maximum,
                   int min_lookback, int max_lookback, int fractal_buffer_pips,
                   bool show_stop_line, CHipoMomentumFractals* fractals)
   {
      m_stop_method = stop_method;
      m_sar_step = sar_step;
      m_sar_maximum = sar_maximum;
      m_min_lookback = min_lookback;
      m_max_lookback = max_lookback;
      m_fractal_buffer_pips = fractal_buffer_pips;
      m_show_stop_line = show_stop_line;
      m_fractals = fractals;
      m_sar_handle = INVALID_HANDLE;
      m_atr_handle = INVALID_HANDLE;
      m_log_buffer = "";
      m_last_flush_time = 0;
   }
   
   //+------------------------------------------------------------------+
   //| تابع راه‌اندازی                                              |
   //+------------------------------------------------------------------+
   bool Initialize()
   {
      if(m_stop_method == STOP_SAR || m_stop_method == STOP_CVT)
      {
         m_sar_handle = iSAR(_Symbol, PERIOD_CURRENT, m_sar_step, m_sar_maximum);
         if(m_sar_handle == INVALID_HANDLE)
         {
            Log("خطا: ایجاد هندل SAR ناموفق بود");
            return false;
         }
      }
      if(m_stop_method == STOP_CVT)
      {
         m_atr_handle = iATR(_Symbol, PERIOD_CURRENT, 14);
         if(m_atr_handle == INVALID_HANDLE)
         {
            Log("خطا: ایجاد هندل ATR ناموفق بود");
            return false;
         }
      }
      Log("تریلینگ استاپ با موفقیت راه‌اندازی شد");
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| تابع توقف                                                    |
   //+------------------------------------------------------------------+
   void Deinitialize()
   {
      if(m_sar_handle != INVALID_HANDLE)
         IndicatorRelease(m_sar_handle);
      if(m_atr_handle != INVALID_HANDLE)
         IndicatorRelease(m_atr_handle);
      if(m_show_stop_line)
         ObjectDelete(0, "HipoStopLine");
      FlushLog();
      Log("تریلینگ استاپ متوقف شد");
   }
   
   //+------------------------------------------------------------------+
   //| تابع محاسبه حد ضرر جدید                                       |
   //+------------------------------------------------------------------+
   double CalculateNewStopLoss(ENUM_POSITION_TYPE pos_type, double current_sl)
   {
      if(TimeCurrent() - m_last_flush_time >= 5)
         FlushLog();
      
      double new_sl = 0.0;
      switch(m_stop_method)
      {
         case STOP_SAR:
         {
            double sar[];
            ArraySetAsSeries(sar, true);
            if(CopyBuffer(m_sar_handle, 0, 1, 1, sar) <= 0)
            {
               Log("خطا در دریافت داده‌های SAR");
               return current_sl;
            }
            new_sl = sar[0];
            break;
         }
         case STOP_CVT:
         {
            double close[];
            ArraySetAsSeries(close, true);
            if(CopyClose(_Symbol, PERIOD_CURRENT, 1, 1, close) <= 0)
            {
               Log("خطا در دریافت قیمت بسته شدن");
               return current_sl;
            }
            int period = CalculateDynamicPeriod(close[0]);
            double high[], low[];
            ArraySetAsSeries(high, true);
            ArraySetAsSeries(low, true);
            if(CopyHigh(_Symbol, PERIOD_CURRENT, 1, period, high) <= 0 ||
               CopyLow(_Symbol, PERIOD_CURRENT, 1, period, low) <= 0)
            {
               Log("خطا در دریافت داده‌های قیمت");
               return current_sl;
            }
            new_sl = (pos_type == POSITION_TYPE_BUY) ? low[ArrayMinimum(low)] : high[ArrayMaximum(high)];
            break;
         }
         case STOP_FRACTAL:
         {
            ArraySetAsSeries(m_fractals.MajorHighs, true);
            ArraySetAsSeries(m_fractals.MajorLows, true);
            for(int i = 0; i < ArraySize(m_fractals.MajorHighs); i++)
            {
               if(pos_type == POSITION_TYPE_BUY && m_fractals.MajorLows[i] != EMPTY_VALUE)
               {
                  new_sl = m_fractals.MajorLows[i] - m_fractal_buffer_pips * _Point;
                  break;
               }
               else if(pos_type == POSITION_TYPE_SELL && m_fractals.MajorHighs[i] != EMPTY_VALUE)
               {
                  new_sl = m_fractals.MajorHighs[i] + m_fractal_buffer_pips * _Point;
                  break;
               }
            }
            if(new_sl == 0.0)
            {
               Log("خطا: فراکتال معتبر یافت نشد");
               return current_sl;
            }
            break;
         }
      }
      if((pos_type == POSITION_TYPE_BUY && new_sl <= current_sl) ||
         (pos_type == POSITION_TYPE_SELL && (new_sl >= current_sl || new_sl == 0.0)))
      {
         return current_sl;
      }
      return new_sl;
   }
   
   //+------------------------------------------------------------------+
   //| تابع به‌روزرسانی نمایش خط استاپ                              |
   //+------------------------------------------------------------------+
   void UpdateVisuals(double stop_price, ENUM_POSITION_TYPE pos_type)
   {
      if(!m_show_stop_line || stop_price == 0.0)
      {
         ObjectDelete(0, "HipoStopLine");
         return;
      }
      if(!ObjectCreate(0, "HipoStopLine", OBJ_HLINE, 0, 0, stop_price))
         return;
      ObjectSetInteger(0, "HipoStopLine", OBJPROP_COLOR, pos_type == POSITION_TYPE_BUY ? clrGreen : clrRed);
      ObjectSetInteger(0, "HipoStopLine", OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, "HipoStopLine", OBJPROP_ZORDER, 1);
      ChartRedraw(0);
   }
};

#endif
