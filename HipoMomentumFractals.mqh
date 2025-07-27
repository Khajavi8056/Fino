//+------------------------------------------------------------------+
//|                                       HipoMomentumFractals_v2.mqh |
//|                              محصولی از: Hipo Algorithm           |
//|                              نسخه: ۲.۰.۰                          |
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

//--- تابع مقایسه برای مرتب‌سازی اشیاء
int CompareFractalObjects(const void& a, const void& b)
{
   FractalObject fa = *(FractalObject*)a;
   FractalObject fb = *(FractalObject*)b;
   if(fa.time < fb.time) return -1;
   if(fa.time > fb.time) return 1;
   return 0;
}


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
      string obj_name = "HipoFractal_" + TimeToString(iTime(_Symbol, m_timeframe, bar_index), "yyyy.MM.dd_HH:mm");

      if(ObjectCreate(0, obj_name, OBJ_ARROW, 0, iTime(_Symbol, m_timeframe, bar_index), price))
      {
         ObjectSetInteger(0, obj_name, OBJPROP_ARROWCODE, symbol_code);
         ObjectSetInteger(0, obj_name, OBJPROP_COLOR, signal_color);
         ObjectSetInteger(0, obj_name, OBJPROP_WIDTH, 1);
         ObjectSetInteger(0, obj_name, OBJPROP_ZORDER, 1);
         ObjectSetDouble(0, obj_name, OBJPROP_PRICE, price);
      }
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
            objects[count].time = ObjectGetInteger(0, name, OBJPROP_TIME);
            count++;
         }
      }
      
      //--- اگر تعداد بیشتر از ۱۰ بود، قدیمی‌ها را پاک کن
      if(count > 10)
      {
         ArraySort(objects, CompareFractalObjects);
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
      
      //--- پاکسازی تمام اشیاء در زمان خروج
      if(m_show_fractals)
      {
         for(int i = ObjectsTotal(0, -1, OBJ_ARROW) - 1; i >= 0; i--)
         {
            string name = ObjectName(0, i, -1, OBJ_ARROW);
            if(StringFind(name, "HipoFractal_") == 0)
               ObjectDelete(0, name);
         }
      }
      
      FlushLog();
      Log("فراکتال‌یاب متوقف شد");
   }

   //+------------------------------------------------------------------+
   //| تابع اصلی محاسبه فراکتال‌ها و واگرایی‌ها
   //+------------------------------------------------------------------+
   void Calculate()
   {
      //--- مدیریت فایل لاگ
      if(TimeCurrent() - m_last_flush_time >= 300) // هر ۵ دقیقه
         FlushLog();

      int bars = Bars(_Symbol, m_timeframe);
      if(bars <= m_fractal_bars * 2) return;

      //--- آماده‌سازی آرایه‌های خروجی
      ArrayResize(MajorHighs, bars, 0);
      ArrayResize(MajorLows, bars, 0);
      ArrayResize(DivergenceSignal, bars, 0);
      ArrayFill(MajorHighs, 0, bars, EMPTY_VALUE);
      ArrayFill(MajorLows, 0, bars, EMPTY_VALUE);
      ArrayFill(DivergenceSignal, 0, bars, 0);

      //--- دریافت داده‌های مکدی و قیمت
      double histogram[];
      if(CopyBuffer(m_macd_handle, 2, 0, bars, histogram) <= 0)
      {
         Log("خطا در دریافت داده‌های هیستوگرام مکدی");
         return;
      }
      double high[], low[];
      if(CopyHigh(_Symbol, m_timeframe, 0, bars, high) <= 0 ||
         CopyLow(_Symbol, m_timeframe, 0, bars, low) <= 0)
      {
         Log("خطا در دریافت داده‌های قیمت");
         return;
      }
      ArraySetAsSeries(histogram, true);
      ArraySetAsSeries(high, true);
      ArraySetAsSeries(low, true);

      //--- حلقه اصلی برای پیدا کردن فراکتال
      for(int i = m_fractal_bars; i < bars - m_fractal_bars; i++)
      {
         bool is_high = true, is_low = true;
         //--- بررسی شرط ساده فراکتال
         for(int j = 1; j <= m_fractal_bars; j++)
         {
            if(histogram[i] < histogram[i - j] || histogram[i] < histogram[i + j]) is_high = false;
            if(histogram[i] > histogram[i - j] || histogram[i] > histogram[i + j]) is_low = false;
         }

         //--- اگر فراکتال پیدا شد
         if(is_high || is_low)
         {
            int divergence_code = DetectDivergence(i, histogram, high, low);
            
            if(is_high)
            {
               double fractal_price = high[i];
               MajorHighs[i] = fractal_price;
               DivergenceSignal[i] = MathAbs(divergence_code);
               DrawFractalSignal(i, fractal_price + SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * _Point, MathAbs(divergence_code), true);
            }
            else if(is_low)
            {
               double fractal_price = low[i];
               MajorLows[i] = fractal_price;
               DivergenceSignal[i] = MathAbs(divergence_code);
               DrawFractalSignal(i, fractal_price - SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * _Point, MathAbs(divergence_code), false);
            }
         }
      }
      
      //--- مدیریت تعداد اشیاء در انتهای هر محاسبه
      ManageFractalObjects();
      ChartRedraw();
   }
};

#endif // HIPO_MOMENTUM_FRACTALS_V2_MQH
