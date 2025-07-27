//+------------------------------------------------------------------+
//|                                          HipoMomentumFractals.mqh |
//|                              محصولی از: Hipo Algorithm           |
//|                              نسخه: ۲.۲.۰ (بهینه شده)              |
//|          کتابخانه شناسایی فراکتال‌های مومنتوم با تشخیص واگرایی    |
//+------------------------------------------------------------------+

#ifndef HIPO_MOMENTUM_FRACTALS_MQH // تغییر نام دیفاین نهایی
#define HIPO_MOMENTUM_FRACTALS_MQH // تغییر نام دیفاین نهایی

//+------------------------------------------------------------------+
//| ساختار برای مدیریت اشیاء گرافیکی
//+------------------------------------------------------------------+
struct FractalObject
{
   string   name;
   datetime time;
};

//+------------------------------------------------------------------+
//| تابع مقایسه‌کننده برای ArraySort (جدید)
//| برای مرتب‌سازی آرایه FractalObject بر اساس زمان به صورت صعودی
//+------------------------------------------------------------------+
int CompareFractalObjects(const int index1, const int index2, const void* array, const int extra_param)
{
   const FractalObject& obj1 = ((FractalObject*)array)[index1];
   const FractalObject& obj2 = ((FractalObject*)array)[index2];

   if (obj1.time < obj2.time) return -1; // obj1 کوچکتر از obj2 است
   if (obj1.time > obj2.time) return 1;  // obj1 بزرگتر از obj2 است
   return 0;                             // برابر هستند
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
   int      DivergenceSignal[];     // خروجی کد واگرایی برای هر فراکتال (0: بدون واگرایی, 1: کلاسیک, 2: مخفی, 3: سه‌قلو)

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
   //| تابع کمکی برای یافتن فراکتال‌های قبلی (اصلاح شده نهایی)
   //| آرگومان price_array و histogram_array به const double* تغییر یافتند.
   //+------------------------------------------------------------------+
   bool FindPreviousFractal(int start_index, int count_back, bool is_high_fractal,
                            const double* price_array, const double* histogram_array, // تغییر نوع آرگومان‌ها
                            double &out_price, double &out_histogram)
   {
      out_price = EMPTY_VALUE;
      out_histogram = EMPTY_VALUE;
      int found_count = 0;
      
      // آرایه‌های MajorHighs و MajorLows (که سراسری هستند) به صورت سری زمانی تنظیم شده‌اند،
      // پس ایندکس 0 جدیدترین کندل است. برای جستجوی فراکتال‌های قبلی (قدیمی‌تر)،
      // باید از ایندکس start_index + 1 به سمت ایندکس‌های بزرگتر حرکت کنیم.
      int max_search_depth = ArraySize(MajorHighs); // یا ArraySize(MajorLows)

      // از start_index + 1 شروع می‌کنیم تا از فراکتال فعلی که در DetectDivergence بررسی می‌شود صرف نظر کنیم.
      for (int i = start_index + 1; i < max_search_depth; i++) 
      {
         if (is_high_fractal)
         {
            if (MajorHighs[i] != EMPTY_VALUE) // اگر ایندکس i یک فراکتال قله معتبر باشد
            {
               // مطمئن شوید که به ایندکس معتبر در price_array و histogram_array دسترسی دارید
               if (i < max_search_depth && i < ArraySize(histogram_array)) // استفاده از ArraySize برای آرایه histogram_array
               {
                   out_price = price_array[i]; 
                   out_histogram = histogram_array[i];
                   found_count++;
                   if (found_count == count_back) return true;
               }
            }
         }
         else // Low fractal
         {
            if (MajorLows[i] != EMPTY_VALUE) // اگر ایندکس i یک فراکتال کف معتبر باشد
            {
               // مطمئن شوید که به ایندکس معتبر در price_array و histogram_array دسترسی دارید
               if (i < max_search_depth && i < ArraySize(histogram_array)) // استفاده از ArraySize برای آرایه histogram_array
               {
                   out_price = price_array[i]; 
                   out_histogram = histogram_array[i];
                   found_count++;
                   if (found_count == count_back) return true;
               }
            }
         }
      }
      return false;
   }


   //+------------------------------------------------------------------+
   //| تشخیص واگرایی (بخش هوشمند و نهایی - تکمیل شده و با مقداردهی اولیه متغیرها و پاس دادن صحیح آرایه)
   //| 0: بدون واگرایی, 1: کلاسیک, 2: مخفی, 3: سه‌قلو
   //+------------------------------------------------------------------+
   int DetectDivergence(int index, const double histogram[], const double price_high[], const double price_low[], bool current_is_high_fractal)
   {
      double current_price = current_is_high_fractal ? price_high[index] : price_low[index];
      double current_hist = histogram[index];

      // --- پیدا کردن فراکتال‌های قبلی برای بررسی واگرایی ---
      double price_prev1 = EMPTY_VALUE, hist_prev1 = EMPTY_VALUE; 
      double price_prev2 = EMPTY_VALUE, hist_prev2 = EMPTY_VALUE; 
      
      // پاس دادن اشاره‌گر به اولین عنصر آرایه
      bool found_p1 = FindPreviousFractal(index, 1, current_is_high_fractal, 
                                          current_is_high_fractal ? &price_high[0] : &price_low[0], // پاس دادن اشاره‌گر
                                          &histogram[0], // پاس دادن اشاره‌گر
                                          price_prev1, hist_prev1);
      
      bool found_p2 = FindPreviousFractal(index, 2, current_is_high_fractal, 
                                          current_is_high_fractal ? &price_high[0] : &price_low[0], // پاس دادن اشاره‌گر
                                          &histogram[0], // پاس دادن اشاره‌گر
                                          price_prev2, hist_prev2);
      
      // --- اولویت اول: واگرایی سه‌قلویی (Tripple Divergence - TD) - کد 3 ---
      if (found_p1 && found_p2 && price_prev1 != EMPTY_VALUE && price_prev2 != EMPTY_VALUE &&
          hist_prev1 != EMPTY_VALUE && hist_prev2 != EMPTY_VALUE) 
      {
         // Triple Regular Divergence (Bearish - قله‌ها): قیمت قله‌های بالاتر، هیستوگرام قله‌های پایین‌تر
         if (current_is_high_fractal && 
             current_price > price_prev1 && price_prev1 > price_prev2 && 
             current_hist < hist_prev1 && hist_prev1 < hist_prev2)        
         {
             Log("واگرایی سه‌قلویی نزولی (TD-R-Bearish) در ایندکس: " + (string)index);
             return 3;
         }
         // Triple Regular Divergence (Bullish - کف‌ها): قیمت کف‌های پایین‌تر، هیستوگرام کف‌های بالاتر
         else if (!current_is_high_fractal && 
                  current_price < price_prev1 && price_prev1 < price_prev2 && 
                  current_hist > hist_prev1 && hist_prev1 > hist_prev2)        
         {
             Log("واگرایی سه‌قلویی صعودی (TD-R-Bullish) در ایندکس: " + (string)index);
             return 3;
         }
         // Triple Hidden Divergence (Bullish - کف‌ها): قیمت کف‌های بالاتر، هیستوگرام کف‌های پایین‌تر (ادامه روند صعودی)
         else if (!current_is_high_fractal && 
                  current_price > price_prev1 && price_prev1 > price_prev2 && 
                  current_hist < hist_prev1 && hist_prev1 < hist_prev2)        
         {
             Log("واگرایی سه‌قلویی مخفی صعودی (TD-H-Bullish) در ایندکس: " + (string)index);
             return 3;
         }
         // Triple Hidden Divergence (Bearish - قله‌ها): قیمت قله‌های پایین‌تر، هیستوگرام قله‌های بالاتر (ادامه روند نزولی)
         else if (current_is_high_fractal && 
                  current_price < price_prev1 && price_prev1 < price_prev2 && 
                  current_hist > hist_prev1 && hist_prev1 > hist_prev2)        
         {
             Log("واگرایی سه‌قلویی مخفی نزولی (TD-H-Bearish) در ایندکس: " + (string)index);
             return 3;
         }
      }

      // --- اولویت دوم: واگرایی کلاسیک (Regular Divergence - RD) - کد 1 ---
      if (found_p1 && price_prev1 != EMPTY_VALUE && hist_prev1 != EMPTY_VALUE) 
      {
         // Regular Divergence (Bearish - قله‌ها): قیمت قله بالاتر، هیستوگرام قله پایین‌تر
         if (current_is_high_fractal && current_price > price_prev1 && current_hist < hist_prev1)
         {
            Log("واگرایی کلاسیک نزولی (RD-Bearish) در ایندکس: " + (string)index);
            return 1;
         }
         // Regular Divergence (Bullish - کف‌ها): قیمت کف پایین‌تر، هیستوگرام کف بالاتر
         else if (!current_is_high_fractal && current_price < price_prev1 && current_hist > hist_prev1)
         {
            Log("واگرایی کلاسیک صعودی (RD-Bullish) در ایندکس: " + (string)index);
            return 1;
         }
      }

      // --- اولویت سوم: واگرایی مخفی (Hidden Divergence - HD) - کد 2 ---
      if (found_p1 && price_prev1 != EMPTY_VALUE && hist_prev1 != EMPTY_VALUE) 
      {
         // Hidden Divergence (Bullish - کف‌ها): قیمت کف بالاتر، هیستوگرام کف پایین‌تر (ادامه روند صعودی)
         if (!current_is_high_fractal && current_price > price_prev1 && current_hist < hist_prev1)
         {
            Log("واگرایی مخفی صعودی (HD-Bullish) در ایندکس: " + (string)index);
            return 2;
         }
         // Hidden Divergence (Bearish - قله‌ها): قیمت قله پایین‌تر، هیستوگرام قله بالاتر (ادامه روند نزولی)
         else if (current_is_high_fractal && current_price < price_prev1 && current_hist > hist_prev1)
         {
            Log("واگرایی مخفی نزولی (HD-Bearish) در ایندکس: " + (string)index);
            return 2;
         }
      }

      // در غیر این صورت، هیچ واگرایی وجود ندارد
      return 0;
   }

   //+------------------------------------------------------------------+
   //| رسم شیء گرافیکی فراکتال روی چارت (تکمیل شده با نماد و رنگ جدید)
   //+------------------------------------------------------------------+
   void DrawFractalSignal(int bar_index, double price, int divergence_code, bool is_high)
   {
      if(!m_show_fractals) return;

      int symbol_code = 139; // کد پیش‌فرض برای سیگنال 0 (بدون واگرایی) - یک دایره توپر
      color signal_color = clrSlateGray; // رنگ پیش‌فرض برای بدون واگرایی

      // تنظیم نماد و رنگ بر اساس نوع واگرایی
      switch(divergence_code)
      {
         case 1: // واگرایی کلاسیک (Regular Divergence)
            symbol_code = is_high ? 234 : 233; // 234: فلش به پایین (نزولی), 233: فلش به بالا (صعودی)
            signal_color = clrDodgerBlue; // آبی روشن برای واگرایی کلاسیک
            break;
         case 2: // واگرایی مخفی (Hidden Divergence)
            symbol_code = is_high ? 233 : 234; // 233: فلش به بالا (صعودی), 234: فلش به پایین (نزولی)
            signal_color = clrPurple; // بنفش برای واگرایی مخفی
            break;
         case 3: // واگرایی سه‌قلویی (Tripple Divergence)
            // از کاراکترهای یونیکد (Wingdings 3) برای فلش‌های دوگانه استفاده می‌کنیم
            // 169: فلش دوگانه به سمت بالا، 170: فلش دوگانه به سمت پایین
            symbol_code = is_high ? 170 : 169; 
            signal_color = clrGold; // طلایی برای واگرایی سه‌قلویی
            break;
         default: // بدون واگرایی
            symbol_code = 139; // دایره توپر
            signal_color = clrSlateGray; // خاکستری تیره
            break;
      }
      
      // نام شیء را با زمان و نوع واگرایی و نوع فراکتال ترکیب می‌کنیم تا منحصر به فرد باشد
      string obj_name = "HipoFractal_" + TimeToString(iTime(_Symbol, m_timeframe, bar_index), "yyyy.MM.dd_HH:mm:ss") + 
                        "_" + IntegerToString(divergence_code) + (is_high ? "_H" : "_L");

      // برای اینکه فلش روی کندل نباشه، کمی آفست می‌دهیم
      double offset_pips = 15; 
      double display_price = price + (is_high ? offset_pips * _Point : -offset_pips * _Point);

      // اگر شیء از قبل وجود ندارد، آن را ایجاد می‌کنیم
      if(ObjectFind(0, obj_name) < 0)
      {
         if(!ObjectCreate(0, obj_name, OBJ_ARROW, 0, iTime(_Symbol, m_timeframe, bar_index), display_price))
         {
             Log("خطا در ایجاد شیء فراکتال: " + obj_name + ", Error: " + (string)GetLastError());
             return;
         }
      }
      
      // ویژگی‌های شیء را تنظیم یا به روزرسانی می‌کنیم
      ObjectSetInteger(0, obj_name, OBJPROP_ARROWCODE, symbol_code);
      ObjectSetInteger(0, obj_name, OBJPROP_COLOR, signal_color);
      ObjectSetInteger(0, obj_name, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, obj_name, OBJPROP_ZORDER, 0); // مطمئن شویم روی چارت دیده می‌شود
      ObjectSetDouble(0, obj_name, OBJPROP_PRICE, display_price); // قیمت نمایش
      ObjectSetInteger(0, obj_name, OBJPROP_SELECTABLE, false); // برای جلوگیری از جابجایی تصادفی توسط کاربر

      // Log("رسم فراکتال: " + obj_name + ", کد واگرایی: " + (string)divergence_code + 
      //     ", قیمت: " + DoubleToString(display_price, _Digits));
   }
   
   //+------------------------------------------------------------------+
   //| مدیریت اشیاء گرافیکی (قانون ۱۰ تایی - اصلاح شده و استفاده از ArraySort با Comparator)
   //+------------------------------------------------------------------+
   void ManageFractalObjects()
   {
      if(!m_show_fractals) return;
      
      FractalObject objects[];
      int count = 0;
      
      // تمام اشیاء فلش که با "HipoFractal_" شروع می‌شوند را جمع‌آوری می‌کنیم
      string obj_name = ObjectName(0, 0, OBJ_ARROW); // شروع از اولین شیء OBJ_ARROW
      while(StringLen(obj_name) > 0)
      {
         if(StringFind(obj_name, "HipoFractal_") == 0) 
         {
            ArrayResize(objects, count + 1);
            objects[count].name = obj_name;
            string time_part = StringSubstr(obj_name, StringLen("HipoFractal_"), 19);
            objects[count].time = StringToTime(time_part);
            if(objects[count].time == 0) 
                objects[count].time = (datetime)ObjectGetInteger(0, obj_name, OBJPROP_TIME);
            count++;
         }
         obj_name = ObjectName(0, obj_name); // رفتن به شیء بعدی
      }
      
      // اگر تعداد اشیاء بیشتر از 10 تا بود، قدیمی‌ترین‌ها را حذف می‌کنیم
      if(count > 10)
      {
         // مرتب‌سازی آرایه بر اساس زمان به صورت صعودی با استفاده از تابع مقایسه‌کننده سفارشی
         ArraySort(objects, CompareFractalObjects); // استفاده از تابع CompareFractalObjects
         
         int to_delete = count - 10;
         for(int i = 0; i < to_delete; i++)
         {
            ObjectDelete(0, objects[i].name);
            // Log("حذف شیء فراکتال قدیمی: " + objects[i].name);
         }
      }
   }

public:
//+==================================================================+
//| توابع عمومی (Public Methods)                                     |
//+==================================================================+

   //+------------------------------------------------------------------+
   //| سازنده کلاس (Constructor - بدون تغییر)
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
   //| تابع راه‌اندازی (بدون تغییر)
   //+------------------------------------------------------------------+
   bool Initialize()
   {
      m_macd_handle = iMACD(_Symbol, m_timeframe, 6, 13, 5, PRICE_CLOSE);
      if(m_macd_handle == INVALID_HANDLE)
      {
         Log("خطا: ایجاد هندل مکدی ناموفق. کد خطا: " + (string)GetLastError());
         return false;
      }
      Log("فراکتال‌یاب با موفقیت راه‌اندازی شد");
      return true;
   }

   //+------------------------------------------------------------------+
   //| تابع توقف (اصلاح شده ObjectsDeleteAll)
   //+------------------------------------------------------------------+
   void Deinitialize()
   {
      if(m_macd_handle != INVALID_HANDLE)
         IndicatorRelease(m_macd_handle);
      
      if(m_show_fractals)
      {
         ObjectsDeleteAll(0, "HipoFractal_", -1, OBJ_ARROW); // اصلاح شده برای حذف بر اساس پیشوند نام
         Log("اشیای فراکتال پاک شدند.");
      }
      
      FlushLog();
      Log("فراکتال‌یاب متوقف شد");
   }

   //+------------------------------------------------------------------+
   //| تابع اصلی محاسبه فراکتال‌ها (نسخه بهینه شده و تکمیل شده)
   //+------------------------------------------------------------------+
   void Calculate()
   {
      if(TimeCurrent() - m_last_flush_time >= 300) 
         FlushLog();

      int total_bars = Bars(_Symbol, m_timeframe);
      if(total_bars <= m_fractal_bars * 2 + 1) 
      {
          return;
      }
      
      ArrayResize(MajorHighs, total_bars); 
      ArrayResize(MajorLows, total_bars);
      ArrayResize(DivergenceSignal, total_bars);
      ArrayFill(MajorHighs, 0, total_bars, EMPTY_VALUE);
      ArrayFill(MajorLows, 0, total_bars, EMPTY_VALUE);
      ArrayFill(DivergenceSignal, 0, total_bars, 0);

      double macd_main[], macd_signal[], macd_histogram[];
      
      if(CopyBuffer(m_macd_handle, 0, 0, total_bars, macd_main) < total_bars || 
         CopyBuffer(m_macd_handle, 1, 0, total_bars, macd_signal) < total_bars)
      {
         Log("خطا در دریافت داده‌های مکدی برای محاسبه: " + (string)GetLastError());
         return;
      }

      ArrayResize(macd_histogram, total_bars);
      for(int i = 0; i < total_bars; i++) macd_histogram[i] = macd_main[i] - macd_signal[i];
      
      double high_prices[], low_prices[];
      if(CopyHigh(_Symbol, m_timeframe, 0, total_bars, high_prices) < total_bars || 
         CopyLow(_Symbol, m_timeframe, 0, total_bars, low_prices) < total_bars)
      {
         Log("خطا در دریافت داده‌های قیمت برای محاسبه: " + (string)GetLastError());
         return;
      }

      ArraySetAsSeries(macd_main, true);
      ArraySetAsSeries(macd_signal, true);
      ArraySetAsSeries(macd_histogram, true);
      ArraySetAsSeries(high_prices, true);
      ArraySetAsSeries(low_prices, true);
      
      for(int i = m_fractal_bars; i < total_bars - m_fractal_bars; i++)
      {
         bool is_high_fractal_macd = true;
         bool is_low_fractal_macd = true;

         for(int j = 1; j <= m_fractal_bars; j++)
         {
            if(macd_histogram[i] < macd_histogram[i - j] || macd_histogram[i] < macd_histogram[i + j])
            {
               is_high_fractal_macd = false;
            }
            if(macd_histogram[i] > macd_histogram[i - j] || macd_histogram[i] > macd_histogram[i + j])
            {
               is_low_fractal_macd = false;
            }
         }

         if(is_high_fractal_macd)
         {
            double fractal_price = high_prices[i]; 
            MajorHighs[i] = fractal_price; 
            int divergence_code = DetectDivergence(i, macd_histogram, high_prices, low_prices, true);
            DivergenceSignal[i] = divergence_code; 
            DrawFractalSignal(i, fractal_price, divergence_code, true);
         }
         
         if(is_low_fractal_macd)
         {
            double fractal_price = low_prices[i]; 
            MajorLows[i] = fractal_price; 
            int divergence_code = DetectDivergence(i, macd_histogram, high_prices, low_prices, false);
            DivergenceSignal[i] = divergence_code; 
            DrawFractalSignal(i, fractal_price, divergence_code, false);
         }
      }
      
      ManageFractalObjects(); 
      ChartRedraw(); 
   }
};

#endif
