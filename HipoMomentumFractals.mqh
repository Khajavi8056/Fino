//+------------------------------------------------------------------+
//|                                       HipoMomentumFractals_v2.1.mqh |
//|                              محصولی از: Hipo Algorithm           |
//|                              نسخه: ۲.۲.۰ (بهینه شده)              |
//|                              تاریخ: ۲۰۲۵/۰۷/۲۷                   |
//|          کتابخانه شناسایی فراکتال‌های مومنتوم با تشخیص واگرایی    |
//+------------------------------------------------------------------+

#ifndef HIPO_MOMENTUM_FRACTALS_V2_MQH
#define HIPO_MOMENTUM_FRACTALS_V2_MQH

//+------------------------------------------------------------------+
//| ساختار برای مدیریت اشیاء گرافیکی
//+------------------------------------------------------------------+
struct FractalObject
{
   string   name;
   datetime time;
};

//+------------------------------------------------------------------+
//| کلاس CHipoMomentumFractals                                      |
//+------------------------------------------------------------------+
class CHipoMomentumFractals
{
public:
   //--- آرایه‌های خروجی عمومی
   double   MajorHighs[];           // خروجی سقف‌های مومنتومی
   double   MajorLows[];            // خروجی کف‌های مومنتومی
   int      DivergenceSignal[];     // خروجی کد واگرایی برای هر فراکتال

private:
   //--- تنظیمات اصلی
   ENUM_TIMEFRAMES m_timeframe;      // تایم‌فریم محاسبات
   int      m_fractal_bars;         // تعداد کندل‌های چپ/راست برای تعریف فراکتال
   bool     m_show_fractals;        // نمایش گرافیکی فراکتال‌ها روی چارت

   //--- هندل اندیکاتورها و متغیرهای داخلی
   int      m_macd_handle;          // هندل اندیکاتور MACD
   string   m_log_buffer;           // بافر برای ذخیره لاگ‌ها
   datetime m_last_flush_time;      // زمان آخرین ذخیره لاگ در فایل

//+==================================================================+
//| توابع خصوصی (Private Methods)                                    |
//+==================================================================+

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
   //| تابع ذخیره لاگ‌ها در فایل
   //+------------------------------------------------------------------+
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
   //| تشخیص واگرایی (بخش هوشمند)
   //| !!! نکته مهم: این توابع فعلا فقط اسکلت هستند و منطق اصلی باید
   //| بر اساس استراتژی دقیق شما پیاده‌سازی شود.
   //+------------------------------------------------------------------+
   int DetectDivergence(int index, const double &histogram[], const double &price_high[], const double &price_low[])
   {
      // اولویت ۱: جستجو برای واگرایی سه‌موجی
      // if(isThreeWaveDivergence(...)) return 3;

      // اولویت ۲: جستجو برای واگرایی مخفی (HD)
      // if(isHiddenDivergence(...)) return 2;

      // اولویت ۳: جستجو برای واگرایی کلاسیک (RD)
      // if(isRegularDivergence(...)) return 1;
      
      // در غیر این صورت، هیچ واگرایی وجود ندارد
      return 0;
   }

   //+------------------------------------------------------------------+
   //| رسم شیء گرافیکی فراکتال روی چارت
   //+------------------------------------------------------------------+
   void DrawFractalSignal(int bar_index, double price, int divergence_code, bool is_high)
   {
      if(!m_show_fractals) return;

      int symbol_code = 139; // کد پیش‌فرض برای سیگنال 0
      switch(divergence_code)
      {
         case 1: symbol_code = 140; break;
         case 2: symbol_code = 141; break;
         case 3: symbol_code = 142; break;
      }
      
      color signal_color = is_high ? clrRed : clrGreen;
      string obj_name = "HipoFractal_" + TimeToString(iTime(_Symbol, m_timeframe, bar_index), "yyyy.MM.dd_HH:mm:ss");

      if(ObjectFind(0, obj_name) < 0)
      {
         if(!ObjectCreate(0, obj_name, OBJ_ARROW, 0, iTime(_Symbol, m_timeframe, bar_index), price))
            return;
      }
      
      ObjectSetInteger(0, obj_name, OBJPROP_ARROWCODE, symbol_code);
      ObjectSetInteger(0, obj_name, OBJPROP_COLOR, signal_color);
      ObjectSetInteger(0, obj_name, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, obj_name, OBJPROP_ZORDER, 0);
      ObjectSetDouble(0, obj_name, OBJPROP_PRICE, price);
   }
   
   //+------------------------------------------------------------------+
   //| مدیریت اشیاء گرافیکی (قانون ۱۰ تایی)
   //+------------------------------------------------------------------+
   void ManageFractalObjects()
   {
      if(!m_show_fractals) return;
      
      FractalObject objects[];
      int count = 0;
      
      //--- جمع‌آوری تمام فراکتال‌های ما
      for(int i = ObjectsTotal(0, -1, OBJ_ARROW) - 1; i >= 0; i--)
      {
         string name = ObjectName(0, i, -1, OBJ_ARROW);
         if(StringFind(name, "HipoFractal_") == 0)
         {
            ArrayResize(objects, count + 1);
            objects[count].name = name;
            objects[count].time = (datetime)ObjectGetInteger(0, name, OBJPROP_TIME);
            count++;
         }
      }
      
      //--- اگر تعداد بیشتر از ۱۰ بود، قدیمی‌ها را با مرتب‌سازی حبابی پاک کن
      if(count > 10)
      {
         //--- مرتب‌سازی حبابی (Bubble Sort)
         for(int i = 0; i < count - 1; i++)
         {
            for(int j = 0; j < count - i - 1; j++)
            {
               if(objects[j].time > objects[j + 1].time)
               {
                  FractalObject temp = objects[j];
                  objects[j] = objects[j + 1];
                  objects[j + 1] = temp;
               }
            }
         }
         
         //--- پاک کردن قدیمی‌ترین‌ها
         int to_delete = count - 10;
         for(int i = 0; i < to_delete; i++)
         {
            ObjectDelete(0, objects[i].name);
         }
      }
   }

public:
//+==================================================================+
//| توابع عمومی (Public Methods)                                     |
//+==================================================================+

   //+------------------------------------------------------------------+
   //| سازنده کلاس (Constructor)
   //+------------------------------------------------------------------+
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
      ArraySetAsSeries(DivergenceSignal, true);
   }

   //+------------------------------------------------------------------+
   //| تابع راه‌اندازی
   //+------------------------------------------------------------------+
   bool Initialize()
   {
      m_macd_handle = iMACD(_Symbol, m_timeframe, 6, 13, 5, PRICE_CLOSE);
      if(m_macd_handle == INVALID_HANDLE)
      {
         Log("خطا: ایجاد هندل مکدی ناموفق");
         return false;
      }
      Log("فراکتال‌یاب با موفقیت راه‌اندازی شد");
      return true;
   }

   //+------------------------------------------------------------------+
   //| تابع توقف
   //+------------------------------------------------------------------+
   void Deinitialize()
   {
      if(m_macd_handle != INVALID_HANDLE)
         IndicatorRelease(m_macd_handle);
      
      if(m_show_fractals)
      {
         ObjectsDeleteAll(0, "HipoFractal_");
      }
      
      FlushLog();
      Log("فراکتال‌یاب متوقف شد");
   }

   //+------------------------------------------------------------------+
   //| تابع اصلی محاسبه فراکتال‌ها (نسخه بهینه شده)
   //+------------------------------------------------------------------+
   void Calculate()
   {
      if(TimeCurrent() - m_last_flush_time >= 300)
         FlushLog();

      // --- بخش جدید: محدود کردن تعداد کندل‌های پردازشی ---
      const int lookback_period = 200; // فقط 200 کندل اخیر را بررسی کن
      int total_bars = Bars(_Symbol, m_timeframe);
      if(total_bars <= m_fractal_bars * 2) return;
      
      // تعداد واقعی کندل برای پردازش، حداکثر 200 تاست
      int bars_to_process = MathMin(total_bars, lookback_period);

      // --- تغییر در اندازه آرایه‌ها و کپی داده‌ها ---
      ArrayResize(MajorHighs, bars_to_process);
      ArrayResize(MajorLows, bars_to_process);
      ArrayResize(DivergenceSignal, bars_to_process);
      ArrayFill(MajorHighs, 0, bars_to_process, EMPTY_VALUE);
      ArrayFill(MajorLows, 0, bars_to_process, EMPTY_VALUE);
      ArrayFill(DivergenceSignal, 0, bars_to_process, 0);

      double macd[], signal[], histogram[];
      // فقط دیتای مورد نیاز را کپی کن
      if(CopyBuffer(m_macd_handle, 0, 0, bars_to_process, macd) <= 0 || CopyBuffer(m_macd_handle, 1, 0, bars_to_process, signal) <= 0)
      {
         Log("خطا در دریافت داده‌های مکدی");
         return;
      }
      ArrayResize(histogram, bars_to_process);
      for(int i = 0; i < bars_to_process; i++) histogram[i] = macd[i] - signal[i];
      
      double high[], low[];
      // فقط دیتای مورد نیاز را کپی کن
      if(CopyHigh(_Symbol, m_timeframe, 0, bars_to_process, high) <= 0 || CopyLow(_Symbol, m_timeframe, 0, bars_to_process, low) <= 0)
      {
         Log("خطا در دریافت داده‌های قیمت");
         return;
      }
      ArraySetAsSeries(histogram, true);
      ArraySetAsSeries(high, true);
      ArraySetAsSeries(low, true);

      // --- تغییر در حلقه اصلی ---
      // حلقه فقط روی کندل‌های اخیر اجرا می‌شود
      for(int i = m_fractal_bars; i < bars_to_process - m_fractal_bars; i++)
      {
         bool is_high = true, is_low = true;
         for(int j = 1; j <= m_fractal_bars; j++)
         {
            if(histogram[i] < histogram[i - j] || histogram[i] < histogram[i + j]) is_high = false;
            if(histogram[i] > histogram[i - j] || histogram[i] > histogram[i + j]) is_low = false;
         }

         if(is_high || is_low)
         {
            int divergence_code = DetectDivergence(i, histogram, high, low);
            
            if(is_high)
            {
               double fractal_price = high[i];
               MajorHighs[i] = fractal_price;
               DivergenceSignal[i] = MathAbs(divergence_code);
               DrawFractalSignal(i, fractal_price + 15 * _Point, MathAbs(divergence_code), true);
            }
            else if(is_low)
            {
               double fractal_price = low[i];
               MajorLows[i] = fractal_price;
               DivergenceSignal[i] = MathAbs(divergence_code);
               DrawFractalSignal(i, fractal_price - 15 * _Point, MathAbs(divergence_code), false);
            }
         }
      }
      
      ManageFractalObjects();
      ChartRedraw();
   }
};

#endif
