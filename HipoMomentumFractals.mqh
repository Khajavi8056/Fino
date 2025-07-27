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
      int handle = FileOpen("HipoMomentals_Log.txt", FILE_WRITE|FILE_TXT|FILE_COMMON);
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
   //| تابع کمکی برای یافتن فراکتال‌های قبلی
   //+------------------------------------------------------------------+
   bool FindPreviousFractal(int start_index, int count_back, bool is_high_fractal,
                            const double &price_array[], const double &histogram_array[],
                            double &out_price, double &out_histogram)
   {
      out_price = EMPTY_VALUE;
      out_histogram = EMPTY_VALUE;
      int found_count = 0;
      for (int i = start_index + 1; i < ArraySize(price_array); i++) // از کندل بعدی شروع کن تا فراکتال تکراری نگیره
      {
         if (is_high_fractal)
         {
            if (MajorHighs[i] != EMPTY_VALUE)
            {
               out_price = price_array[i]; // باید از آرایه قیمت اصلی بگیریم، نه MajorHighs
               out_histogram = histogram_array[i];
               found_count++;
               if (found_count == count_back) return true;
            }
         }
         else // Low fractal
         {
            if (MajorLows[i] != EMPTY_VALUE)
            {
               out_price = price_array[i]; // باید از آرایه قیمت اصلی بگیریم، نه MajorLows
               out_histogram = histogram_array[i];
               found_count++;
               if (found_count == count_back) return true;
            }
         }
      }
      return false;
   }

   //+------------------------------------------------------------------+
   //| تشخیص واگرایی (بخش هوشمند و نهایی)
   //+------------------------------------------------------------------+
   int DetectDivergence(int index, const double &histogram[], const double &price_high[], const double &price_low[], bool current_is_high_fractal)
   {
      double current_price = current_is_high_fractal ? price_high[index] : price_low[index];
      double current_hist = histogram[index];

      // --- واگرایی سه‌قلویی (Tripple Divergence - TD) - کد 3 ---
      // اینجا منطق باید بر اساس آخرین سه فراکتال متوالی هم‌جهت بررسی بشه.
      // پیاده‌سازی این بخش نیاز به دنبال کردن فراکتال‌های قبلی داره که کمی پیچیده‌تره.
      // برای شروع، ما میایم دو فراکتال قبلی رو چک می‌کنیم و اگه اون‌ها هم در یک راستا باشند،
      // می‌تونیم اون رو به عنوان سه‌قلویی در نظر بگیریم.
      // یا اینکه باید تابع FindPreviousFractal رو طوری تغییر بدیم که فراکتال‌های متوالی رو پیدا کنه.

      // برای سادگی و شروع، بیایم چک کنیم آیا فراکتال فعلی و دو فراکتال قبلی، یک الگوی TD رو می‌سازند
      // این بخش کمی نیاز به دقت بیشتر در انتخاب فراکتال‌های متوالی دارد.
      // فعلا فرض می‌کنیم که FindPreviousFractal فراکتال‌های "واقعی" را در تاریخچه برمی‌گرداند.
      double price_prev1, hist_prev1;
      double price_prev2, hist_prev2;
      double price_prev3, hist_prev3; // برای واگرایی سه‌قلویی، نیاز به 3 فراکتال قبلی هست

      // پیدا کردن 3 فراکتال قبلی (برای واگرایی 3 قله/کف)
      bool found_p1 = FindPreviousFractal(index, 1, current_is_high_fractal, current_is_high_fractal ? price_high : price_low, histogram, price_prev1, hist_prev1);
      bool found_p2 = FindPreviousFractal(index, 2, current_is_high_fractal, current_is_high_fractal ? price_high : price_low, histogram, price_prev2, hist_prev2);
      bool found_p3 = FindPreviousFractal(index, 3, current_is_high_fractal, current_is_high_fractal ? price_high : price_low, histogram, price_prev3, hist_prev3);

      if (found_p1 && found_p2 && found_p3)
      {
         // Triple Regular Divergence (Bullish) - 3 قله بالاتر در قیمت، 3 قله پایین‌تر در هیستوگرام
         if (current_is_high_fractal && current_price > price_prev1 && price_prev1 > price_prev2 && current_hist < hist_prev1 && hist_prev1 < hist_prev2)
         {
             Log("واگرایی سه‌قلویی نزولی (قیمت رو به بالا، مکدی رو به پایین) در ایندکس: " + (string)index);
             return 3;
         }
         // Triple Regular Divergence (Bearish) - 3 کف پایین‌تر در قیمت، 3 کف بالاتر در هیستوگرام
         else if (!current_is_high_fractal && current_price < price_prev1 && price_prev1 < price_prev2 && current_hist > hist_prev1 && hist_prev1 > hist_prev2)
         {
             Log("واگرایی سه‌قلویی صعودی (قیمت رو به پایین، مکدی رو به بالا) در ایندکس: " + (string)index);
             return 3;
         }
         // Triple Hidden Divergence (Bullish) - 3 کف بالاتر در قیمت، 3 کف پایین‌تر در هیستوگرام
         else if (!current_is_high_fractal && current_price > price_prev1 && price_prev1 > price_prev2 && current_hist < hist_prev1 && hist_prev1 < hist_prev2)
         {
             Log("واگرایی سه‌قلویی مخفی صعودی (قیمت رو به بالا، مکدی رو به پایین) در ایندکس: " + (string)index);
             return 3;
         }
         // Triple Hidden Divergence (Bearish) - 3 قله پایین‌تر در قیمت، 3 قله بالاتر در هیستوگرام
         else if (current_is_high_fractal && current_price < price_prev1 && price_prev1 < price_prev2 && current_hist > hist_prev1 && hist_prev1 > hist_prev2)
         {
             Log("واگرایی سه‌قلویی مخفی نزولی (قیمت رو به پایین، مکدی رو به بالا) در ایندکس: " + (string)index);
             return 3;
         }
      }

      // اگر سه قله/کف متوالی پیدا نشد یا شرط واگرایی سه‌قلویی برقرار نشد، سراغ دو قله/کف می‌ریم
      // پیدا کردن 2 فراکتال قبلی
      if (found_p1 && found_p2)
      {
         // --- واگرایی کلاسیک (Regular Divergence - RD) - کد 1 ---
         // برای قله‌ها (نزولی)
         if (current_is_high_fractal && current_price > price_prev1 && current_hist < hist_prev1)
         {
            Log("واگرایی کلاسیک نزولی (قیمت رو به بالا، مکدی رو به پایین) در ایندکس: " + (string)index);
            return 1;
         }
         // برای کف‌ها (صعودی)
         else if (!current_is_high_fractal && current_price < price_prev1 && current_hist > hist_prev1)
         {
            Log("واگرایی کلاسیک صعودی (قیمت رو به پایین، مکدی رو به بالا) در ایندکس: " + (string)index);
            return 1;
         }

         // --- واگرایی مخفی (Hidden Divergence - HD) - کد 2 ---
         // برای قله‌ها (صعودی - ادامه روند صعودی)
         else if (current_is_high_fractal && current_price < price_prev1 && current_hist > hist_prev1)
         {
            Log("واگرایی مخفی صعودی (قیمت رو به پایین، مکدی رو به بالا) در ایندکس: " + (string)index);
            return 2;
         }
         // برای کف‌ها (نزولی - ادامه روند نزولی)
         else if (!current_is_high_fractal && current_price > price_prev1 && current_hist < hist_prev1)
         {
            Log("واگرایی مخفی نزولی (قیمت رو به بالا، مکدی رو به پایین) در ایندکس: " + (string)index);
            return 2;
         }
      }

      // اگر هیچ واگرایی پیدا نشد
      return 0;
   }

   //+------------------------------------------------------------------+
   //| رسم شیء گرافیکی فراکتال روی چارت
   //+------------------------------------------------------------------+
   void DrawFractalSignal(int bar_index, double price, int divergence_code, bool is_high)
   {
      if(!m_show_fractals) return;

      int symbol_code = 139; // کد پیش‌فرض برای سیگنال 0 (بدون واگرایی)
      color signal_color = is_high ? clrRed : clrGreen;

      switch(divergence_code)
      {
         case 1: // کلاسیک
            symbol_code = is_high ? 234 : 233; // ▲ (Up Arrow) for bearish RD, ▼ (Down Arrow) for bullish RD
            signal_color = clrDodgerBlue; // رنگ متفاوت برای کلاسیک
            break;
         case 2: // مخفی
            symbol_code = is_high ? 233 : 234; // ▼ (Down Arrow) for bullish HD, ▲ (Up Arrow) for bearish HD
            signal_color = clrPurple; // رنگ متفاوت برای مخفی
            break;
         case 3: // سه‌قلویی
            symbol_code = is_high ? 169 : 170; // ⮝ (Double Up Arrow) for bearish TD, ⮟ (Double Down Arrow) for bullish TD
            signal_color = clrGold; // رنگ متفاوت برای سه‌قلویی
            break;
      }
      
      string obj_name = "HipoFractal_" + TimeToString(iTime(_Symbol, m_timeframe, bar_index), "yyyy.MM.dd_HH:mm:ss") + "_" + IntegerToString(divergence_code) + "_" + (is_high ? "H" : "L");

      // فقط اگر شیء موجود نیست، آن را ایجاد کن
      if(ObjectFind(0, obj_name) < 0)
      {
         // برای فلش، قیمت را کمی بالاتر یا پایین‌تر از فراکتال قرار می‌دهیم که روی کندل نباشد
         double offset = 15 * _Point;
         if(!ObjectCreate(0, obj_name, OBJ_ARROW, 0, iTime(_Symbol, m_timeframe, bar_index), price + (is_high ? offset : -offset)))
         {
             Log("خطا در ایجاد شیء فراکتال: " + obj_name);
             return;
         }
      }
      // اگر شیء موجود بود، آن را به‌روزرسانی کن (موقعیت، رنگ و نماد)
      ObjectSetInteger(0, obj_name, OBJPROP_ARROWCODE, symbol_code);
      ObjectSetInteger(0, obj_name, OBJPROP_COLOR, signal_color);
      ObjectSetInteger(0, obj_name, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, obj_name, OBJPROP_ZORDER, 0);
      ObjectSetDouble(0, obj_name, OBJPROP_PRICE, price + (is_high ? offset : -offset));
      // ObjectSetInteger(0, obj_name, OBJPROP_SELECTABLE, false); // برای جلوگیری از جابجایی تصادفی

      // لاگ برای دیباگ
      Log("رسم فراکتال: " + obj_name + ", کد واگرایی: " + (string)divergence_code);
   }
   
   //+------------------------------------------------------------------+
   //| مدیریت اشیاء گرافیکی (قانون ۱۰ تایی)
   //+------------------------------------------------------------------+
   void ManageFractalObjects()
   {
      if(!m_show_fractals) return;
      
      // ابتدا تمام اشیاء HipoFractal_ را جمع آوری کنید
      // نیاز به اصلاح: ObjectTotal(0, -1, OBJ_ARROW) فقط فلش‌ها را برمی‌گرداند.
      // اما اگر اسم‌گذاری‌های شما خاص باشد، باید از ObjectName استفاده کنید.
      string current_fractal_objects[];
      int current_fractal_count = 0;

      for (int i = 0; i < ObjectsTotal(0, -1, OBJ_ARROW); i++)
      {
         string obj_name = ObjectName(0, i, -1, OBJ_ARROW);
         if (StringFind(obj_name, "HipoFractal_") == 0)
         {
            ArrayResize(current_fractal_objects, current_fractal_count + 1);
            current_fractal_objects[current_fractal_count] = obj_name;
            current_fractal_count++;
         }
      }

      // حالا، فقط ۱۰ شیء اخیر را نگه دارید و بقیه را حذف کنید
      // برای این کار، باید بر اساس زمان ایجاد یا زمان کندل مرتب‌سازی کنیم
      // اما چون ObjectCreate همیشه یک شیء جدید ایجاد می‌کند، ما به سادگی می‌توانیم
      // اشیایی را که در این بار ایجاد نشده‌اند، بررسی و حذف کنیم.

      // یک رویکرد ساده‌تر: هر بار فراکتال‌های جدید را رسم کن
      // و در DrawFractalSignal چک کن که آیا شیء از قبل وجود دارد یا نه.
      // اگر می‌خواهی فقط ۱۰ تای آخر را نگه داری، باید یک لیست از اشیاء فعال را نگه داری
      // و وقتی شیء جدیدی اضافه شد و تعداد از ۱۰ بیشتر شد، قدیمی‌ترین را حذف کنی.
      // این بخش فعلا همان منطق قبلی را با نام‌گذاری بهتر پیاده می‌کند
      
      FractalObject objects[];
      int count = 0;
      
      for(int i = ObjectsTotal(0, -1, OBJ_ARROW) - 1; i >= 0; i--)
      {
         string name = ObjectName(0, i, -1, OBJ_ARROW);
         if(StringFind(name, "HipoFractal_") == 0) // فقط فراکتال‌های خودمان را در نظر بگیر
         {
            ArrayResize(objects, count + 1);
            objects[count].name = name;
            // زمان شیء را از نامش استخراج کنید یا هنگام ایجاد ذخیره کنید
            // فرض می‌کنیم فرمت نام HipoFractal_yyyy.MM.dd_HH:mm:ss_Code_HL است
            string time_part = StringSubstr(name, StringLen("HipoFractal_"), 19);
            objects[count].time = StringToTime(time_part);
            if(objects[count].time == 0) // اگر تبدیل نشد، از OBJPROP_TIME استفاده کن
                objects[count].time = (datetime)ObjectGetInteger(0, name, OBJPROP_TIME);
            count++;
         }
      }
      
      if(count > 10)
      {
         // مرتب‌سازی برای یافتن قدیمی‌ترین‌ها
         ArraySort(objects, 0, WHOLE_ARRAY, MODE_ASCEND); // بر اساس زمان صعودی
         
         int to_delete = count - 10;
         for(int i = 0; i < to_delete; i++)
         {
            ObjectDelete(0, objects[i].name);
            Log("حذف شیء فراکتال قدیمی: " + objects[i].name);
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
      // پارامترهای MACD را می‌توانید به عنوان ورودی اکسپرت اضافه کنید
      // فعلا از مقادیر ثابت استفاده می‌کنیم (FastEMA, SlowEMA, SignalSMA)
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
   //| تابع توقف
   //+------------------------------------------------------------------+
   void Deinitialize()
   {
      if(m_macd_handle != INVALID_HANDLE)
         IndicatorRelease(m_macd_handle);
      
      if(m_show_fractals)
      {
         // پاک کردن تمام اشیاء فراکتال که خودمان ایجاد کرده‌ایم
         ObjectsDeleteAll(0, 0, OBJ_ARROW, -1, -1, "HipoFractal_");
         Log("اشیای فراکتال پاک شدند.");
      }
      
      FlushLog();
      Log("فراکتال‌یاب متوقف شد");
   }

   //+------------------------------------------------------------------+
   //| تابع اصلی محاسبه فراکتال‌ها (نسخه بهینه شده)
   //+------------------------------------------------------------------+
   void Calculate()
   {
      if(TimeCurrent() - m_last_flush_time >= 300) // هر 5 دقیقه لاگ رو ذخیره کن
         FlushLog();

      const int lookback_period = 200; // فقط 200 کندل اخیر را بررسی کن
      int total_bars = Bars(_Symbol, m_timeframe);
      if(total_bars <= m_fractal_bars * 2 + 1) // حداقل تعداد کندل برای تشخیص فراکتال + کندل 0
      {
          Log("تعداد کندل‌های کافی برای تشخیص فراکتال وجود ندارد: " + (string)total_bars);
          return;
      }
      
      int bars_to_process = MathMin(total_bars - 1, lookback_period); // از کندل 1 تا bars_to_process-1

      ArrayResize(MajorHighs, total_bars); // برای پوشش کل چارت
      ArrayResize(MajorLows, total_bars);
      ArrayResize(DivergenceSignal, total_bars);
      ArrayFill(MajorHighs, 0, total_bars, EMPTY_VALUE);
      ArrayFill(MajorLows, 0, total_bars, EMPTY_VALUE);
      ArrayFill(DivergenceSignal, 0, total_bars, 0);

      double macd_main[], macd_signal[], macd_histogram[];
      
      // کپی کردن داده‌های MACD از کندل 0 تا Bars-1
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
      
      // حلقه فقط روی کندل‌های اخیر اجرا می‌شود
      // از m_fractal_bars شروع می‌کنیم تا مطمئن شویم داده‌های کافی برای بررسی چپ و راست داریم
      // تا total_bars - m_fractal_bars - 1 ادامه می‌دهیم
      for(int i = m_fractal_bars; i < total_bars - m_fractal_bars; i++)
      {
         bool is_high_fractal_macd = true;
         bool is_low_fractal_macd = true;

         // بررسی فراکتال MACD (بر اساس هیستوگرام)
         for(int j = 1; j <= m_fractal_bars; j++)
         {
            // برای قله (High Fractal)
            if(macd_histogram[i] < macd_histogram[i - j] || macd_histogram[i] < macd_histogram[i + j])
            {
               is_high_fractal_macd = false;
            }
            // برای کف (Low Fractal)
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
            DivergenceSignal[i] = divergence_code; // ذخیره کد واگرایی
            DrawFractalSignal(i, fractal_price, divergence_code, true);
            // Log("قله فراکتال در ایندکس " + (string)i + " با قیمت " + DoubleToString(fractal_price, _Digits) + " و واگرایی: " + (string)divergence_code);
         }
         
         if(is_low_fractal_macd)
         {
            double fractal_price = low_prices[i];
            MajorLows[i] = fractal_price;
            int divergence_code = DetectDivergence(i, macd_histogram, high_prices, low_prices, false);
            DivergenceSignal[i] = divergence_code; // ذخیره کد واگرایی
            DrawFractalSignal(i, fractal_price, divergence_code, false);
            // Log("کف فراکتال در ایندکس " + (string)i + " با قیمت " + DoubleToString(fractal_price, _Digits) + " و واگرایی: " + (string)divergence_code);
         }
      }
      
      ManageFractalObjects(); // مدیریت اشیاء گرافیکی (فقط ۱۰ تای آخر باقی می‌مانند)
      ChartRedraw();
   }
};
