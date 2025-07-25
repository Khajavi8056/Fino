```
//+------------------------------------------------------------------+
//|                                          HipoMomentumFractals.mqh |
//|                              محصولی از: Hipo Algorithm           |
   //                              |
//|                              نسخه: ۱.۱.۰                          |
   //                              تاریخ: ۲۰۲۵/07/25                   |
//|                              کتابخانه شناسایی فراکتال‌های مومنتوم |
//+------------------------------------------------------------------+

#ifndef HIPO_MOMENTUM_FRACTALS_MQH
#define HIPO_MOMENTUM_FRACTALS_MQH

//+------------------------------------------------------------------+
//| کلاس CHipoMomentumFractals                                      |
//+------------------------------------------------------------------+
class CHipoMomentumFractals
{
private:
   ENUM_TIMEFRAMES m_timeframe;   // تایم‌فریم محاسبات
   int m_fractal_bars;            // تعداد کندل‌های چپ/راست
   bool m_show_fractals;          // نمایش فراکتال‌ها
   int m_macd_handle;             // هندل مکدی
   string m_log_buffer;           // بافر لاگ
   datetime m_last_flush_time;    // زمان برای آخرین فلاش لاگ

   //+------------------------------------------------------------------+
   //| تابع لاگ‌گیری
   //+------------------------------------------------------------------+
   void Log(string message)
   {
      string log_entry = TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES|TIME_SECONDS) + ": " + message + "\n";
      m_log_buffer += log_entry;
      Print(log_entry);
   }
   
   //+------------------------------------------------------------------+
   //| تابع فلاش لاگ به فایل                                          |
   | این تابع لاگ‌ها را در فایل ذخیره می‌کند
   +------------------------------------------------------------------+
   void FlushLog()
   {
      if(m_log_buffer == "") return;
      int handle = FileOpen("HipoMomentumFractals_Log.txt", FILE_WRITE|FILE_TXT|FILE_COMMON);
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
   | تابع ایجاد شیء گرافیکی
   | برای رسم فلش یا لوزی روی چارت
   +------------------------------------------------------------------+
   bool CreateFractalObject(string name, datetime time, double price, int code, color clr)
   {
      if(!ObjectCreate(0, name, OBJ_ARROW, 0, time, price))
         return false;
      ObjectSetInteger(0, name, OBJPROP_ARROWCODE, code);
      ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, name, OBJPROP_ZORDER, 1);
      return true;
   }
   
   //+------------------------------------------------------------------+
   | تابع حذف اشیاء گرافیکی
   | حذف تمام اشیاء فلشکل برای پاکسازی چارت
   +------------------------------------------------------------------+
   void ClearFractalObjects()
   {
      for(int i = ObjectsTotal(0, 0, OBJ_ARROW) - 1; i >= 0; i--)
      {
         string name = ObjectName(0, i, 0, OBJ_ARROW);
         if(StringFind(name, "Fractal_") == 0)
            ObjectDelete(0, name);
      }
   }

public:
   double MajorHighs[];           // بافر سقف‌های ماژور
   double MajorLows[];            // بافر کف‌های ماژور
   double MinorHighs[];           // بافر سقف‌های مینور
   double MinorLows[];            // بافر کف‌های مینور
   
   //+------------------------------------------------------------------+
   | سازنده کلاس
   | مقداردهی اولیه متغیرها
   +------------------------------------------------------------------+
   CHipoMomentumFractals(ENUM_TIMEFRAMES timeframe, int fractal_bars, bool show_fractals)
   {
      m_timeframe = timeframe;
      m_fractal_bars = fractal_bars;
      m_show_fractals = show_fractals;
      m_macd_handle = INVALID_HANDLE;
      m_log_buffer = "";
      m_last_flush_time = 0;
      ArraySetAsSeries(MajorHighs, true);
      ArraySetAsSeries(MajorLows, true);
      ArraySetAsSeries(MinorHighs, true);
      ArraySetAsSeries(MinorLows, true);
   }
   
   //+------------------------------------------------------------------+
   | تابع راه‌اندازی
   | ایجاد هندل مکدی و آماده‌سازی بافرها
   +------------------------------------------------------------------+
   bool Initialize()
   {
      m_macd_handle = iMACD(_Symbol, m_timeframe, 6, 13, 5, PRICE_CLOSE);
      if(m_macd_handle == INVALID_HANDLE)
      {
         Log("خطا: ایجاد هندل مکدی ناموفق");
         return false;
      }
      ArrayResize(MajorHighs, Bars(_Symbol, m_timeframe));
      ArrayResize(MajorLows, Bars(_Symbol, m_timeframe));
      ArrayResize(MinorHighs, Bars(_Symbol, m_timeframe));
      ArrayResize(MinorLows, Bars(_Symbol, m_timeframe));
      ArrayFill(MajorHighs, 0, ArraySize(MajorHighs), EMPTY_VALUE);
      ArrayFill(MajorLows, 0, ArraySize(MajorLows), EMPTY_VALUE);
      ArrayFill(MinorHighs, 0, ArraySize(MinorHighs), EMPTY_VALUE);
      ArrayFill(MinorLows, 0, ArraySize(MinorLows), EMPTY_VALUE);
      Log("فراکتال‌یاب با موفقیت راه‌اندازی شد");
      return true;
   }
   
   //+------------------------------------------------------------------+
   | تابع توقف
   | آزادسازی منابع و پاکسازی اشیاء گرافیکی
   +------------------------------------------------------------------+
   void Deinitialize()
   {
      if(m_macd_handle != INVALID_HANDLE)
         IndicatorRelease(m_macd_handle);
      if(m_show_fractals)
         ClearFractalObjects();
      FlushLog();
      Log("فراکتال‌یاب متوقف شد");
   }
   
   //+------------------------------------------------------------------+
   | تابع محاسبه فراکتال‌ها
   | شناسایی فراکتال‌ها بر اساس هیستوگرام مکدی و قیمت
   +------------------------------------------------------------------+
   void CalculateFractals()
   {
      if(TimeCurrent() - m_last_flush_time >= 5)
         FlushLog();
      
      int bars = Bars(_Symbol, m_timeframe);
      ArrayResize(MajorHighs, bars);
      ArrayResize(MajorLows, bars);
      ArrayResize(MinorHighs, bars);
      ArrayResize(MinorLows, bars);
      ArrayFill(MajorHighs, 0, bars, EMPTY_VALUE);
      ArrayFill(MajorLows, 0, bars, EMPTY_VALUE);
      ArrayFill(MinorHighs, 0, bars, EMPTY_VALUE);
      ArrayFill(MinorLows, 0, bars, EMPTY_VALUE);
      
      double macd[], signal[], histogram[];
      ArraySetAsSeries(macd, true);
      ArraySetAsSeries(signal, true);
      ArraySetAsSeries(histogram, true);
      if(CopyBuffer(m_macd_handle, 0, 0, bars, macd) <= 0 ||
         CopyBuffer(m_macd_handle, 1, 0, bars, signal) <= 0)
      {
         Log("خطا در دریافت داده‌های مکدی");
         return;
      }
      ArrayResize(histogram, bars);
      for(int i = 0; i < bars; i++)
         histogram[i] = macd[i] - signal[i];
      
      double high[], low[];
      ArraySetAsSeries(high, true);
      ArraySetAsSeries(low, true);
      if(CopyHigh(_Symbol, m_timeframe, 0, bars, high) <= 0 ||
         CopyLow(_Symbol, m_timeframe, 0, bars, low) <= 0)
      {
         Log("خطا در دریافت داده‌های قیمت");
         return;
      }
      
      for(int i = m_fractal_bars; i < bars - m_fractal_bars; i++)
      {
         bool is_high = true, is_low = true;
         for(int j = 1; j <= m_fractal_bars; j++)
         {
            if(histogram[i] <= histogram[i - j] || histogram[i] <= histogram[i + j])
               is_high = false;
            if(histogram[i] >= histogram[i - j] || histogram[i] >= histogram[i + j])
               is_low = false;
         }
         
         if(is_high || is_low)
         {
            double max_high = high[i];
            double min_low = low[i];
            for(int j = -m_fractal_bars; j <= m_fractal_bars; j++)
            {
               max_high = MathMax(max_high, high[i + j]);
               min_low = MathMin(min_low, low[i + j]);
            }
            
            bool is_major = false;
            if(is_high && histogram[i] > 0)
            {
               is_major = true;
               for(int j = i - m_fractal_bars; j <= i + m_fractal_bars; j++)
               {
                  if(j != i && histogram[j] > 0 && histogram[j] > histogram[i])
                  {
                     is_major = false;
                     break;
                  }
               }
               if(is_major)
                  MajorHighs[i] = max_high;
               else
                  MinorHighs[i] = max_high;
            }
            else if(is_low && histogram[i] < 0)
            {
               is_major = true;
               for(int j = i - m_fractal_bars; j <= i + m_fractal_bars; j++)
               {
                  if(j != i && histogram[j] < 0 && histogram[j] < histogram[i])
                  {
                     is_major = false;
                     break;
                  }
               }
               if(is_major)
                  MajorLows[i] = min_low;
               else
                  MinorLows[i] = min_low;
            }
            
            if(m_show_fractals)
            {
               string name = "Fractal_" + (is_high ? "High_" : "Low_") + TimeToString(iTime(_Symbol, m_timeframe, i));
               if(is_high)
               {
                  CreateFractalObject(name, iTime(_Symbol, m_timeframe, i), max_high,
                                     is_major ? 218 : 159, is_major ? clrGreen : clrBlue);
               }
               else if(is_low)
               {
                  CreateFractalObject(name, iTime(_Symbol, m_timeframe, i), min_low,
                                     is_major ? 217 : 159, is_major ? clrRed : clrBlue);
               }
            }
         }
      }
   }
};

#endif
