//+------------------------------------------------------------------+
//| کتابخانه HipoFibonacci                                           |
//| تیم سازنده: HipoAlgorithm                                       |
//| نسخه: 1.2                                                        |
//| توضیح: این کتابخانه برای شناسایی نواحی ورود معاملاتی (Golden Zones) |
//| بر اساس منطق فیبوناچی و اندیکاتور Fineflow طراحی شده است.      |
//| قابلیت‌ها: شناسایی سقف‌ها و کف‌های معتبر، رسم فیبوناچی‌های مادر، |
//| زنده و نهایی، پشتیبانی از دو سناریوی معاملاتی (پولبک و اکستنشن)، |
//| پنل وضعیت، و گزارش‌دهی به اکسپرت میزبان.                       |
//| تاریخ: 21 جولای 2025                                            |
//+------------------------------------------------------------------+

#property copyright "HipoAlgorithm"
#property link      "https://hipoalgorithm.com"
#property version   "1.2"
#property strict

//+------------------------------------------------------------------+
//| تعاریف و ساختارها                                               |
//+------------------------------------------------------------------+

//--- حالت‌های دستور اکسپرت
enum E_SignalType {
   SIGNAL_BUY,        // دستور خرید
   SIGNAL_SELL,       // دستور فروش
   STOP_SEARCH        // توقف جستجو
};

//--- وضعیت‌های کتابخانه
enum E_Status {
   WAITING_FOR_COMMAND,                   // منتظر دستور
   SEARCHING_FOR_ANCHOR_LOW,             // جستجوی کف لنگرگاه (خرید)
   SEARCHING_FOR_ANCHOR_HIGH,            // جستجوی سقف لنگرگاه (فروش)
   MONITORING_SCENARIO_1_PROGRESS,       // پایش سناریو ۱
   SCENARIO_1_AWAITING_PULLBACK,         // انتظار پولبک سناریو ۱
   SCENARIO_1_AWAITING_BREAKOUT,         // انتظار شکست سناریو ۱
   SCENARIO_1_CONFIRMED_AWAITING_ENTRY,  // سناریو ۱ تأیید شده، انتظار ورود
   SCENARIO_2_ACTIVE_TARGETING_EXTENSION, // پایش سناریو ۲
   SCENARIO_2_CONFIRMED_AWAITING_ENTRY,  // سناریو ۲ تأیید شده، انتظار ورود
   ENTRY_ZONE_ACTIVE                     // ناحیه ورود فعال
};

//--- نوع فیبوناچی
enum E_FiboType {
   FIBO_MOTHER,       // فیبوی مادر
   FIBO_INTERMEDIATE, // فیبوی زنده
   FIBO_FINAL         // فیبوی نهایی
};

//--- روش‌های شناسایی Fineflow
enum E_DetectionMethod {
   METHOD_SIMPLE,         // روش ساده (فراکتال)
   METHOD_SEQUENTIAL,     // روش پلکانی
   METHOD_POWER_SWING,    // روش فیلتر قدرت
   METHOD_ZIGZAG,         // روش زیگزاگ
   METHOD_BREAK_OF_STRUCTURE, // روش شکست ساختار (BOS)
   METHOD_MARKET_STRUCTURE_SHIFT // روش تغییر ساختار بازار (MSS)
};

//--- معیار پلکانی
enum E_SequentialCriterion {
   CRITERION_HIGH,    // استفاده از High
   CRITERION_LOW,     // استفاده از Low
   CRITERION_OPEN,    // استفاده از Open
   CRITERION_CLOSE    // استفاده از Close
};

//--- ساختار برای ذخیره نقاط سقف و کف
struct PeakValley {
   double price;      // قیمت
   datetime time;     // زمان
   int position;      // موقعیت کندل
};

//--- ساختار تنظیمات
struct HipoSettings {
   // تنظیمات عمومی
   ENUM_TIMEFRAMES CalculationTimeframe; // تایم‌فریم محاسباتی
   bool Enable_Drawing;                  // فعال‌سازی رسم آبجکت‌ها
   bool Enable_Logging;                  // فعال‌سازی لاگ‌نویسی
   bool Enable_Status_Panel;             // فعال‌سازی پنل وضعیت
   int MaxCandles;                       // حداکثر کندل‌های پردازش‌شده
   double MarginPips;                    // حاشیه شکست لنگرگاه (پیپ)

   // تنظیمات Fineflow
   bool EnforceStrictSequence;           // توالی اجباری سقف/کف
   E_DetectionMethod DetectionMethod;    // روش شناسایی
   int Lookback;                         // تعداد کندل‌های نگاه به عقب/جلو
   int SequentialLookback;               // تعداد کندل‌های پلکانی
   bool UseStrictSequential;             // حالت سخت‌گیرانه پلکانی
   E_SequentialCriterion SequentialCriterion; // معیار پلکانی
   int AtrPeriod;                        // دوره ATR
   double AtrMultiplier;                 // ضریب ATR
   int ZigZagDepth;                      // عمق زیگزاگ
   double ZigZagDeviation;               // انحراف زیگزاگ (پیپ)

   // تنظیمات فیبوناچی
   double EntryZone_LowerLevel;          // سطح پایین ناحیه طلایی
   double EntryZone_UpperLevel;          // سطح بالای ناحیه طلایی
   double ExtensionZone_LowerLevel;      // سطح پایین ناحیه اکستنشن
   double ExtensionZone_UpperLevel;      // سطح بالای ناحیه اکستنشن
   double FibonacciLevels[10];           // آرایه سطوح فیبوناچی
   int FibonacciLevelsCount;             // تعداد سطوح فیبوناچی

   // تنظیمات گرافیکی
   color MotherFibo_Color;               // رنگ فیبوی مادر
   color IntermediateFibo_Color;         // رنگ فیبوی زنده
   color BuyEntryFibo_Color;             // رنگ فیبوی نهایی خرید
   color SellEntryFibo_Color;            // رنگ فیبوی نهایی فروش
};

//+------------------------------------------------------------------+
//| کلاس کتابخانه HipoFibonacci                                     |
//+------------------------------------------------------------------+
class CHipoFibonacci {
private:
   //--- متغیرهای داخلی
   HipoSettings settings;                // تنظیمات کتابخانه
   E_SignalType signalType;              // نوع دستور اکسپرت
   E_Status currentStatus;               // وضعیت فعلی
   datetime anchorID;                    // شناسه ساختار (datetime لنگرگاه)
   PeakValley anchor;                    // لنگرگاه (Anchor_Low یا Anchor_High)
   PeakValley mother;                    // سقف/کف مادر
   PeakValley temporary;                 // سقف/کف موقت (سناریو ۱)
   PeakValley final;                     // سقف/کف نهایی (سناریو ۲)
   datetime entryZoneActivationTime;     // زمان فعال شدن ناحیه طلایی
   string finalFiboScenario;             // سناریو فیبوی نهایی (Scenario1/Scenario2)
   bool isEntryZoneActive;               // وضعیت ناحیه طلایی
   int handleATR;                        // هندل ATR
   double atrBuffer[];                   // بافر ATR
   double swingHighs_Array[2];           // آرایه برای ذخیره دو سقف سوینگ
   double swingLows_Array[2];            // آرایه برای ذخیره دو کف سوینگ
   datetime swingHighs_Time[2];          // زمان سقف‌های سوینگ
   datetime swingLows_Time[2];           // زمان کف‌های سوینگ
   PeakValley lastConfirmedPeak;         // آخرین قله تأییدشده
   PeakValley lastConfirmedValley;       // آخرین دره تأییدشده
   PeakValley candidatePeak;             // کاندیدای قله
   PeakValley candidateValley;           // کاندیدای دره
   bool isPullbackStarted;               // نشانگر شروع پولبک در سناریو ۲

   //--- آرایه‌های داده برای بهینه‌سازی
   double high[], low[], open[], close[];
   datetime time[];
   int rates_total;

   //--- توابع کمکی Fineflow
   bool FindValley(datetime &time, double &price, int &position);
   bool FindPeak(datetime &time, double &price, int &position);
   bool IsSequential(int i, bool isPeak);
   bool CheckSequential(int i, bool isPeak, const double &values[]);
   bool HasEnoughPower(int i, bool isPeak, double price, datetime time);
   bool IsZigZag(int i, bool isPeak);
   void IdentifySwingPoints(int i, bool &isSwingHigh, bool &isSwingLow);
   void IdentifyMSS(int i, bool &isFinalPeak, bool &isFinalValley);
   void UpdateSwingArray(double &array[], datetime &timeArray[], double price, datetime time);

   //--- توابع کمکی گرافیکی و محاسباتی
   void CreateStatusPanel();
   void UpdateStatusPanel();
   void DrawFibo(E_FiboType type, double price1, double price2, datetime time1, datetime time2, color clr, string scenario = "");
   void DeleteFiboObjects();
   double CalculateFiboLevelPrice(E_FiboType type, double level);
   void ProcessBuyLogic();
   void ProcessSellLogic();

public:
   //--- سازنده و مخرب
   CHipoFibonacci();
   ~CHipoFibonacci();

   //--- توابع اصلی
   void Init(HipoSettings &inputSettings);
   void ReceiveCommand(E_SignalType type, ENUM_TIMEFRAMES timeframe);
   void OnNewCandle(const int rates_total, const datetime &time[], const double &open[], const double &high[], const double &low[], const double &close[]);
   bool IsEntryZoneActive() { return isEntryZoneActive; }
   datetime GetEntryZoneActivationTime() { return entryZoneActivationTime; }
   string GetFinalFiboScenario() { return finalFiboScenario; }
   E_Status GetCurrentStatus() { return currentStatus; }
   double GetFiboLevelPrice(E_FiboType type, double level) { return CalculateFiboLevelPrice(type, level); }
};

//+------------------------------------------------------------------+
//| سازنده کلاس                                                     |
//+------------------------------------------------------------------+
CHipoFibonacci::CHipoFibonacci() {
   signalType = STOP_SEARCH;
   currentStatus = WAITING_FOR_COMMAND;
   anchorID = 0;
   anchor.price = 0;
   anchor.time = 0;
   anchor.position = 0;
   mother.price = 0;
   mother.time = 0;
   mother.position = 0;
   temporary.price = 0;
   temporary.time = 0;
   temporary.position = 0;
   final.price = 0;
   final.time = 0;
   final.position = 0;
   entryZoneActivationTime = 0;
   finalFiboScenario = "";
   isEntryZoneActive = false;
   handleATR = INVALID_HANDLE;
   lastConfirmedPeak.price = 0;
   lastConfirmedValley.price = 0;
   candidatePeak.price = 0;
   candidateValley.price = 0;
   isPullbackStarted = false;
   ArrayInitialize(swingHighs_Array, 0);
   ArrayInitialize(swingLows_Array, 0);
   ArrayInitialize(swingHighs_Time, 0);
   ArrayInitialize(swingLows_Time, 0);
}

//+------------------------------------------------------------------+
//| مخرب کلاس                                                       |
//+------------------------------------------------------------------+
CHipoFibonacci::~CHipoFibonacci() {
   if(handleATR != INVALID_HANDLE)
      IndicatorRelease(handleATR);
   DeleteFiboObjects();
   ObjectDelete(0, "HipoFibonacci_Panel");
}

//+------------------------------------------------------------------+
//| تابع مقداردهی اولیه                                            |
//+------------------------------------------------------------------+
void CHipoFibonacci::Init(HipoSettings &inputSettings) {
   //--- تنظیمات پیش‌فرض
   settings.CalculationTimeframe = inputSettings.CalculationTimeframe == 0 ? PERIOD_CURRENT : inputSettings.CalculationTimeframe;
   settings.Enable_Drawing = inputSettings.Enable_Drawing;
   settings.Enable_Logging = inputSettings.Enable_Logging;
   settings.Enable_Status_Panel = inputSettings.Enable_Status_Panel;
   settings.MaxCandles = inputSettings.MaxCandles > 0 ? inputSettings.MaxCandles : 500;
   settings.MarginPips = inputSettings.MarginPips > 0 ? inputSettings.MarginPips : 1.0;

   //--- تنظیمات Fineflow
   settings.EnforceStrictSequence = inputSettings.EnforceStrictSequence;
   settings.DetectionMethod = inputSettings.DetectionMethod;
   settings.Lookback = inputSettings.Lookback > 0 ? inputSettings.Lookback : 3;
   settings.SequentialLookback = inputSettings.SequentialLookback > 0 ? inputSettings.SequentialLookback : 2;
   settings.UseStrictSequential = inputSettings.UseStrictSequential;
   settings.SequentialCriterion = inputSettings.SequentialCriterion;
   settings.AtrPeriod = inputSettings.AtrPeriod > 0 ? inputSettings.AtrPeriod : 14;
   settings.AtrMultiplier = inputSettings.AtrMultiplier > 0 ? inputSettings.AtrMultiplier : 2.5;
   settings.ZigZagDepth = inputSettings.ZigZagDepth > 0 ? inputSettings.ZigZagDepth : 12;
   settings.ZigZagDeviation = inputSettings.ZigZagDeviation > 0 ? inputSettings.ZigZagDeviation : 5.0;

   //--- تنظیمات فیبوناچی
   settings.EntryZone_LowerLevel = inputSettings.EntryZone_LowerLevel > 0 ? inputSettings.EntryZone_LowerLevel : 50.0;
   settings.EntryZone_UpperLevel = inputSettings.EntryZone_UpperLevel > settings.EntryZone_LowerLevel ? inputSettings.EntryZone_UpperLevel : 68.0;
   settings.ExtensionZone_LowerLevel = inputSettings.ExtensionZone_LowerLevel > 100 ? inputSettings.ExtensionZone_LowerLevel : 150.0;
   settings.ExtensionZone_UpperLevel = inputSettings.ExtensionZone_UpperLevel > settings.ExtensionZone_LowerLevel ? inputSettings.ExtensionZone_UpperLevel : 200.0;
   settings.FibonacciLevelsCount = inputSettings.FibonacciLevelsCount > 0 && inputSettings.FibonacciLevelsCount <= 10 ? inputSettings.FibonacciLevelsCount : 8;
   if(inputSettings.FibonacciLevelsCount == 0) {
      settings.FibonacciLevels[0] = 0.0;
      settings.FibonacciLevels[1] = 30.0;
      settings.FibonacciLevels[2] = 50.0;
      settings.FibonacciLevels[3] = 68.0;
      settings.FibonacciLevels[4] = 100.0;
      settings.FibonacciLevels[5] = 150.0;
      settings.FibonacciLevels[6] = 200.0;
      settings.FibonacciLevels[7] = 250.0;
   } else {
      ArrayCopy(settings.FibonacciLevels, inputSettings.FibonacciLevels, 0, 0, inputSettings.FibonacciLevelsCount);
   }

   //--- تنظیمات گرافیکی
   settings.MotherFibo_Color = inputSettings.MotherFibo_Color == clrNONE ? clrGray : inputSettings.MotherFibo_Color;
   settings.IntermediateFibo_Color = inputSettings.IntermediateFibo_Color == clrNONE ? clrLemonChiffon : inputSettings.IntermediateFibo_Color;
   settings.BuyEntryFibo_Color = inputSettings.BuyEntryFibo_Color == clrNONE ? clrLightGreen : inputSettings.BuyEntryFibo_Color;
   settings.SellEntryFibo_Color = inputSettings.SellEntryFibo_Color == clrNONE ? clrRed : inputSettings.SellEntryFibo_Color;

   //--- تنظیم آرایه ATR
   ArrayResize(atrBuffer, settings.MaxCandles);

   //--- ایجاد هندل ATR
   if(settings.DetectionMethod == METHOD_POWER_SWING) {
      handleATR = iATR(_Symbol, settings.CalculationTimeframe, settings.AtrPeriod);
      if(handleATR == INVALID_HANDLE && settings.Enable_Logging) {
         Print("خطا در ایجاد هندل ATR");
      }
   }

   //--- ایجاد پنل وضعیت
   if(settings.Enable_Status_Panel) {
      CreateStatusPanel();
   }
}

//+------------------------------------------------------------------+
//| تابع دریافت دستور از اکسپرت                                     |
//+------------------------------------------------------------------+
void CHipoFibonacci::ReceiveCommand(E_SignalType type, ENUM_TIMEFRAMES timeframe) {
   if(type == STOP_SEARCH) {
      if(settings.Enable_Logging) Print("دریافت دستور توقف جستجو");
      DeleteFiboObjects();
      signalType = STOP_SEARCH;
      currentStatus = WAITING_FOR_COMMAND;
      anchorID = 0;
      anchor.price = 0;
      anchor.time = 0;
      anchor.position = 0;
      mother.price = 0;
      mother.time = 0;
      mother.position = 0;
      temporary.price = 0;
      temporary.time = 0;
      temporary.position = 0;
      final.price = 0;
      final.time = 0;
      final.position = 0;
      isEntryZoneActive = false;
      entryZoneActivationTime = 0;
      finalFiboScenario = "";
      isPullbackStarted = false;
      UpdateStatusPanel();
   } else {
      signalType = type;
      settings.CalculationTimeframe = timeframe == 0 ? PERIOD_CURRENT : timeframe;
      currentStatus = (type == SIGNAL_BUY) ? SEARCHING_FOR_ANCHOR_LOW : SEARCHING_FOR_ANCHOR_HIGH;
      anchorID = 0;
      anchor.price = 0;
      anchor.time = 0;
      anchor.position = 0;
      mother.price = 0;
      mother.time = 0;
      mother.position = 0;
      temporary.price = 0;
      temporary.time = 0;
      temporary.position = 0;
      final.price = 0;
      final.time = 0;
      final.position = 0;
      isEntryZoneActive = false;
      entryZoneActivationTime = 0;
      finalFiboScenario = "";
      isPullbackStarted = false;
      if(settings.Enable_Logging) Print("دریافت دستور ", EnumToString(type), " در تایم‌فریم ", EnumToString(timeframe));
      UpdateStatusPanel();
   }
}

//+------------------------------------------------------------------+
//| تابع پردازش کندل جدید                                           |
//+------------------------------------------------------------------+
void CHipoFibonacci::OnNewCandle(const int rates_total_input, const datetime &time_input[], const double &open_input[], const double &high_input[], const double &low_input[], const double &close_input[]) {
   if(currentStatus == WAITING_FOR_COMMAND) return;

   //--- کپی داده‌ها برای بهینه‌سازی
   rates_total = rates_total_input;
   ArrayResize(high, rates_total);
   ArrayResize(low, rates_total);
   ArrayResize(open, rates_total);
   ArrayResize(close, rates_total);
   ArrayResize(time, rates_total);
   ArrayCopy(high, high_input, 0, 0, rates_total);
   ArrayCopy(low, low_input, 0, 0, rates_total);
   ArrayCopy(open, open_input, 0, 0, rates_total);
   ArrayCopy(close, close_input, 0, 0, rates_total);
   ArrayCopy(time, time_input, 0, 0, rates_total);

   //--- کپی مقادیر ATR
   if(settings.DetectionMethod == METHOD_POWER_SWING && handleATR != INVALID_HANDLE) {
      if(CopyBuffer(handleATR, 0, 0, MathMin(rates_total, settings.MaxCandles), atrBuffer) <= 0) {
         if(settings.Enable_Logging) Print("خطا در کپی مقادیر ATR");
         return;
      }
   }

   //--- پردازش منطق خرید
   if(signalType == SIGNAL_BUY) {
      ProcessBuyLogic();
   }
   //--- پردازش منطق فروش
   else if(signalType == SIGNAL_SELL) {
      ProcessSellLogic();
   }

   UpdateStatusPanel();
}

//+------------------------------------------------------------------+
//| پردازش منطق خرید                                                |
//+------------------------------------------------------------------+
void CHipoFibonacci::ProcessBuyLogic() {
   //--- مرحله ۱: جستجوی Anchor_Low
   if(currentStatus == SEARCHING_FOR_ANCHOR_LOW) {
      datetime valleyTime;
      double valleyPrice;
      int valleyPosition;
      if(FindValley(valleyTime, valleyPrice, valleyPosition)) {
         anchor.price = valleyPrice;
         anchor.time = valleyTime;
         anchor.position = valleyPosition;
         anchorID = valleyTime;
         datetime peakTime;
         double peakPrice;
         int peakPosition;
         if(FindPeak(peakTime, peakPrice, peakPosition) && peakTime < valleyTime) {
            mother.price = peakPrice;
            mother.time = peakTime;
            mother.position = peakPosition;
            if(settings.Enable_Drawing) {
               DrawFibo(FIBO_MOTHER, anchor.price, mother.price, anchor.time, mother.time, settings.MotherFibo_Color);
            }
            if(settings.Enable_Logging) {
               Print("Anchor_Low یافت شد در قیمت ", valleyPrice, " در ", TimeToString(valleyTime), ", Mother_High در ", peakPrice);
            }
            currentStatus = MONITORING_SCENARIO_1_PROGRESS;
         }
      } else {
         if(settings.Enable_Logging) Print("هیچ دره‌ای در ", settings.MaxCandles, " کندل یافت نشد");
      }
   }
   //--- مرحله ۲: پایش سناریو ۱
   else if(currentStatus == MONITORING_SCENARIO_1_PROGRESS) {
      if(settings.Enable_Drawing) {
         DrawFibo(FIBO_INTERMEDIATE, anchor.price, high[1], anchor.time, time[1], settings.IntermediateFibo_Color);
      }
      if(low[1] < anchor.price - settings.MarginPips * _Point) {
         if(settings.Enable_Logging) Print("شکست ساختار: لنگرگاه شکسته در قیمت ", low[1]);
         DeleteFiboObjects();
         currentStatus = (signalType != STOP_SEARCH) ? SEARCHING_FOR_ANCHOR_LOW : WAITING_FOR_COMMAND;
         return;
      }
      if(high[1] > mother.price) {
         currentStatus = SCENARIO_2_ACTIVE_TARGETING_EXTENSION;
         isPullbackStarted = false;
         final.price = 0;
         final.time = 0;
         final.position = 0;
         if(settings.Enable_Logging) Print("ورود به سناریو ۲: شکست Mother_High در ", high[1]);
         return;
      }
      //--- ثبت سقف موقت
      if(high[1] > temporary.price) {
         temporary.price = high[1];
         temporary.time = time[1];
         temporary.position = 1;
      }
      double goldenZoneLow = CalculateFiboLevelPrice(FIBO_INTERMEDIATE, settings.EntryZone_LowerLevel);
      double goldenZoneHigh = CalculateFiboLevelPrice(FIBO_INTERMEDIATE, settings.EntryZone_UpperLevel);
      if(close[1] >= goldenZoneLow && close[1] <= goldenZoneHigh && temporary.price > 0) {
         currentStatus = SCENARIO_1_AWAITING_BREAKOUT;
         if(settings.Enable_Logging) Print("پولبک به ناحیه طلایی در قیمت ", close[1], "، انتظار شکست Temporary_High در ", temporary.price);
      }
   }
   //--- مرحله ۳: انتظار شکست Temporary_High
   else if(currentStatus == SCENARIO_1_AWAITING_BREAKOUT) {
      if(low[1] < anchor.price - settings.MarginPips * _Point) {
         if(settings.Enable_Logging) Print("شکست ساختار: لنگرگاه شکسته در قیمت ", low[1]);
         DeleteFiboObjects();
         currentStatus = (signalType != STOP_SEARCH) ? SEARCHING_FOR_ANCHOR_LOW : WAITING_FOR_COMMAND;
         return;
      }
      if(high[1] > temporary.price) {
         if(settings.Enable_Drawing) {
            DrawFibo(FIBO_FINAL, anchor.price, high[1], anchor.time, time[1], settings.BuyEntryFibo_Color, "Scenario1");
         }
         final.price = high[1];
         final.time = time[1];
         final.position = 1;
         finalFiboScenario = "Scenario1";
         currentStatus = SCENARIO_1_CONFIRMED_AWAITING_ENTRY;
         if(settings.Enable_Logging) Print("سناریو ۱ تأیید شد، Temporary_High شکسته شد در ", high[1]);
      }
   }
   //--- مرحله ۴: انتظار ورود سناریو ۱
   else if(currentStatus == SCENARIO_1_CONFIRMED_AWAITING_ENTRY) {
      double goldenZoneLow = CalculateFiboLevelPrice(FIBO_FINAL, settings.EntryZone_LowerLevel);
      double goldenZoneHigh = CalculateFiboLevelPrice(FIBO_FINAL, settings.EntryZone_UpperLevel);
      if(close[1] >= goldenZoneLow && close[1] <= goldenZoneHigh) {
         isEntryZoneActive = true;
         entryZoneActivationTime = time[1];
         currentStatus = ENTRY_ZONE_ACTIVE;
         if(settings.Enable_Logging) Print("ناحیه طلایی فعال در قیمت ", close[1], " در ", TimeToString(time[1]));
      }
   }
   //--- مرحله ۵: پایش سناریو ۲
   else if(currentStatus == SCENARIO_2_ACTIVE_TARGETING_EXTENSION) {
      if(low[1] < anchor.price - settings.MarginPips * _Point) {
         if(settings.Enable_Logging) Print("شکست ساختار: لنگرگاه شکسته در قیمت ", low[1]);
         DeleteFiboObjects();
         currentStatus = (signalType != STOP_SEARCH) ? SEARCHING_FOR_ANCHOR_LOW : WAITING_FOR_COMMAND;
         return;
      }
      if(high[1] > CalculateFiboLevelPrice(FIBO_MOTHER, 200.0)) {
         if(settings.Enable_Logging) Print("شکست ساختار: اکستنشن شکسته در قیمت ", high[1]);
         DeleteFiboObjects();
         currentStatus = (signalType != STOP_SEARCH) ? SEARCHING_FOR_ANCHOR_LOW : WAITING_FOR_COMMAND;
         return;
      }
      double extensionLow = CalculateFiboLevelPrice(FIBO_MOTHER, settings.ExtensionZone_LowerLevel);
      double extensionHigh = CalculateFiboLevelPrice(FIBO_MOTHER, settings.ExtensionZone_UpperLevel);
      if(high[1] >= extensionLow) {
         if(high[1] > final.price) {
            final.price = high[1];
            final.time = time[1];
            final.position = 1;
            if(settings.Enable_Drawing) {
               DrawFibo(FIBO_FINAL, anchor.price, final.price, anchor.time, final.time, settings.IntermediateFibo_Color, "Scenario2");
            }
            if(settings.Enable_Logging && final.price > 0) {
               Print("آپدیت سقف نهایی سناریو ۲ در قیمت ", final.price, " در ", TimeToString(final.time));
            }
         }
         if(high[1] < final.price && final.price > 0) {
            isPullbackStarted = true;
            if(settings.Enable_Drawing) {
               DrawFibo(FIBO_FINAL, anchor.price, final.price, anchor.time, final.time, settings.BuyEntryFibo_Color, "Scenario2");
            }
            finalFiboScenario = "Scenario2";
            currentStatus = SCENARIO_2_CONFIRMED_AWAITING_ENTRY;
            if(settings.Enable_Logging) Print("سناریو ۲ تأیید شد، پولبک از سقف نهایی ", final.price, " شروع شد");
         }
      }
   }
   //--- مرحله ۶: انتظار ورود سناریو ۲
   else if(currentStatus == SCENARIO_2_CONFIRMED_AWAITING_ENTRY) {
      if(low[1] < anchor.price - settings.MarginPips * _Point) {
         if(settings.Enable_Logging) Print("شکست ساختار: لنگرگاه شکسته در قیمت ", low[1]);
         DeleteFiboObjects();
         currentStatus = (signalType != STOP_SEARCH) ? SEARCHING_FOR_ANCHOR_LOW : WAITING_FOR_COMMAND;
         return;
      }
      if(high[1] > CalculateFiboLevelPrice(FIBO_MOTHER, 200.0)) {
         if(settings.Enable_Logging) Print("شکست ساختار: اکستنشن شکسته در قیمت ", high[1]);
         DeleteFiboObjects();
         currentStatus = (signalType != STOP_SEARCH) ? SEARCHING_FOR_ANCHOR_LOW : WAITING_FOR_COMMAND;
         return;
      }
      double goldenZoneLow = CalculateFiboLevelPrice(FIBO_FINAL, settings.EntryZone_LowerLevel);
      double goldenZoneHigh = CalculateFiboLevelPrice(FIBO_FINAL, settings.EntryZone_UpperLevel);
      if(close[1] >= goldenZoneLow && close[1] <= goldenZoneHigh) {
         isEntryZoneActive = true;
         entryZoneActivationTime = time[1];
         currentStatus = ENTRY_ZONE_ACTIVE;
         if(settings.Enable_Logging) Print("ناحیه طلایی فعال در قیمت ", close[1], " در ", TimeToString(time[1]));
      }
   }
   //--- مرحله ۷: ناحیه ورود فعال
   else if(currentStatus == ENTRY_ZONE_ACTIVE) {
      // منتظر دستور STOP_SEARCH از اکسپرت برای ریست
   }
}

//+------------------------------------------------------------------+
//| پردازش منطق فروش                                                |
//+------------------------------------------------------------------+
void CHipoFibonacci::ProcessSellLogic() {
   //--- مرحله ۱: جستجوی Anchor_High
   if(currentStatus == SEARCHING_FOR_ANCHOR_HIGH) {
      datetime peakTime;
      double peakPrice;
      int peakPosition;
      if(FindPeak(peakTime, peakPrice, peakPosition)) {
         anchor.price = peakPrice;
         anchor.time = peakTime;
         anchor.position = peakPosition;
         anchorID = peakTime;
         datetime valleyTime;
         double valleyPrice;
         int valleyPosition;
         if(FindValley(valleyTime, valleyPrice, valleyPosition) && valleyTime < peakTime) {
            mother.price = valleyPrice;
            mother.time = valleyTime;
            mother.position = valleyPosition;
            if(settings.Enable_Drawing) {
               DrawFibo(FIBO_MOTHER, anchor.price, mother.price, anchor.time, mother.time, settings.MotherFibo_Color);
            }
            if(settings.Enable_Logging) {
               Print("Anchor_High یافت شد در قیمت ", peakPrice, " در ", TimeToString(peakTime), ", Mother_Low در ", valleyPrice);
            }
            currentStatus = MONITORING_SCENARIO_1_PROGRESS;
         }
      } else {
         if(settings.Enable_Logging) Print("هیچ قله‌ای در ", settings.MaxCandles, " کندل یافت نشد");
      }
   }
   //--- مرحله ۲: پایش سناریو ۱
   else if(currentStatus == MONITORING_SCENARIO_1_PROGRESS) {
      if(settings.Enable_Drawing) {
         DrawFibo(FIBO_INTERMEDIATE, anchor.price, low[1], anchor.time, time[1], settings.IntermediateFibo_Color);
      }
      if(high[1] > anchor.price + settings.MarginPips * _Point) {
         if(settings.Enable_Logging) Print("شکست ساختار: لنگرگاه شکسته در قیمت ", high[1]);
         DeleteFiboObjects();
         currentStatus = (signalType != STOP_SEARCH) ? SEARCHING_FOR_ANCHOR_HIGH : WAITING_FOR_COMMAND;
         return;
      }
      if(low[1] < mother.price) {
         currentStatus = SCENARIO_2_ACTIVE_TARGETING_EXTENSION;
         isPullbackStarted = false;
         final.price = 0;
         final.time = 0;
         final.position = 0;
         if(settings.Enable_Logging) Print("ورود به سناریو ۲: شکست Mother_Low در ", low[1]);
         return;
      }
      //--- ثبت کف موقت
      if(low[1] < temporary.price || temporary.price == 0) {
         temporary.price = low[1];
         temporary.time = time[1];
         temporary.position = 1;
      }
      double goldenZoneLow = CalculateFiboLevelPrice(FIBO_INTERMEDIATE, settings.EntryZone_LowerLevel);
      double goldenZoneHigh = CalculateFiboLevelPrice(FIBO_INTERMEDIATE, settings.EntryZone_UpperLevel);
      if(close[1] >= goldenZoneLow && close[1] <= goldenZoneHigh && temporary.price > 0) {
         currentStatus = SCENARIO_1_AWAITING_BREAKOUT;
         if(settings.Enable_Logging) Print("پولبک به ناحیه طلایی در قیمت ", close[1], "، انتظار شکست Temporary_Low در ", temporary.price);
      }
   }
   //--- مرحله ۳: انتظار شکست Temporary_Low
   else if(currentStatus == SCENARIO_1_AWAITING_BREAKOUT) {
      if(high[1] > anchor.price + settings.MarginPips * _Point) {
         if(settings.Enable_Logging) Print("شکست ساختار: لنگرگاه شکسته در قیمت ", high[1]);
         DeleteFiboObjects();
         currentStatus = (signalType != STOP_SEARCH) ? SEARCHING_FOR_ANCHOR_HIGH : WAITING_FOR_COMMAND;
         return;
      }
      if(low[1] < temporary.price) {
         if(settings.Enable_Drawing) {
            DrawFibo(FIBO_FINAL, anchor.price, low[1], anchor.time, time[1], settings.SellEntryFibo_Color, "Scenario1");
         }
         final.price = low[1];
         final.time = time[1];
         final.position = 1;
         finalFiboScenario = "Scenario1";
         currentStatus = SCENARIO_1_CONFIRMED_AWAITING_ENTRY;
         if(settings.Enable_Logging) Print("سناریو ۱ تأیید شد، Temporary_Low شکسته شد در ", low[1]);
      }
   }
   //--- مرحله ۴: انتظار ورود سناریو ۱
   else if(currentStatus == SCENARIO_1_CONFIRMED_AWAITING_ENTRY) {
      double goldenZoneLow = CalculateFiboLevelPrice(FIBO_FINAL, settings.EntryZone_LowerLevel);
      double goldenZoneHigh = CalculateFiboLevelPrice(FIBO_FINAL, settings.EntryZone_UpperLevel);
      if(close[1] >= goldenZoneLow && close[1] <= goldenZoneHigh) {
         isEntryZoneActive = true;
         entryZoneActivationTime = time[1];
         currentStatus = ENTRY_ZONE_ACTIVE;
         if(settings.Enable_Logging) Print("ناحیه طلایی فعال در قیمت ", close[1], " در ", TimeToString(time[1]));
      }
   }
   //--- مرحله ۵: پایش سناریو ۲
   else if(currentStatus == SCENARIO_2_ACTIVE_TARGETING_EXTENSION) {
      if(high[1] > anchor.price + settings.MarginPips * _Point) {
         if(settings.Enable_Logging) Print("شکست ساختار: لنگرگاه شکسته در قیمت ", high[1]);
         DeleteFiboObjects();
         currentStatus = (signalType != STOP_SEARCH) ? SEARCHING_FOR_ANCHOR_HIGH : WAITING_FOR_COMMAND;
         return;
      }
      if(low[1] < CalculateFiboLevelPrice(FIBO_MOTHER, 200.0)) {
         if(settings.Enable_Logging) Print("شکست ساختار: اکستنشن شکسته در قیمت ", low[1]);
         DeleteFiboObjects();
         currentStatus = (signalType != STOP_SEARCH) ? SEARCHING_FOR_ANCHOR_HIGH : WAITING_FOR_COMMAND;
         return;
      }
      double extensionLow = CalculateFiboLevelPrice(FIBO_MOTHER, settings.ExtensionZone_LowerLevel);
      double extensionHigh = CalculateFiboLevelPrice(FIBO_MOTHER, settings.ExtensionZone_UpperLevel);
      if(low[1] <= extensionLow) {
         if(low[1] < final.price || final.price == 0) {
            final.price = low[1];
            final.time = time[1];
            final.position = 1;
            if(settings.Enable_Drawing) {
               DrawFibo(FIBO_FINAL, anchor.price, final.price, anchor.time, final.time, settings.IntermediateFibo_Color, "Scenario2");
            }
            if(settings.Enable_Logging && final.price > 0) {
               Print("آپدیت کف نهایی سناریو ۲ در قیمت ", final.price, " در ", TimeToString(final.time));
            }
         }
         if(low[1] > final.price && final.price > 0) {
            isPullbackStarted = true;
            if(settings.Enable_Drawing) {
               DrawFibo(FIBO_FINAL, anchor.price, final.price, anchor.time, final.time, settings.SellEntryFibo_Color, "Scenario2");
            }
            finalFiboScenario = "Scenario2";
            currentStatus = SCENARIO_2_CONFIRMED_AWAITING_ENTRY;
            if(settings.Enable_Logging) Print("سناریو ۲ تأیید شد، پولبک از کف نهایی ", final.price, " شروع شد");
         }
      }
   }
   //--- مرحله ۶: انتظار ورود سناریو ۲
   else if(currentStatus == SCENARIO_2_CONFIRMED_AWAITING_ENTRY) {
      if(high[1] > anchor.price + settings.MarginPips * _Point) {
         if(settings.Enable_Logging) Print("شکست ساختار: لنگرگاه شکسته در قیمت ", high[1]);
         DeleteFiboObjects();
         currentStatus = (signalType != STOP_SEARCH) ? SEARCHING_FOR_ANCHOR_HIGH : WAITING_FOR_COMMAND;
         return;
      }
      if(low[1] < CalculateFiboLevelPrice(FIBO_MOTHER, 200.0)) {
         if(settings.Enable_Logging) Print("شکست ساختار: اکستنشن شکسته در قیمت ", low[1]);
         DeleteFiboObjects();
         currentStatus = (signalType != STOP_SEARCH) ? SEARCHING_FOR_ANCHOR_HIGH : WAITING_FOR_COMMAND;
         return;
      }
      double goldenZoneLow = CalculateFiboLevelPrice(FIBO_FINAL, settings.EntryZone_LowerLevel);
      double goldenZoneHigh = CalculateFiboLevelPrice(FIBO_FINAL, settings.EntryZone_UpperLevel);
      if(close[1] >= goldenZoneLow && close[1] <= goldenZoneHigh) {
         isEntryZoneActive = true;
         entryZoneActivationTime = time[1];
         currentStatus = ENTRY_ZONE_ACTIVE;
         if(settings.Enable_Logging) Print("ناحیه طلایی فعال در قیمت ", close[1], " در ", TimeToString(time[1]));
      }
   }
   //--- مرحله ۷: ناحیه ورود فعال
   else if(currentStatus == ENTRY_ZONE_ACTIVE) {
      // منتظر دستور STOP_SEARCH از اکسپرت برای ریست
   }
}

//+------------------------------------------------------------------+
//| تابع پیدا کردن دره (از Fineflow)                                |
//+------------------------------------------------------------------+
bool CHipoFibonacci::FindValley(datetime &time, double &price, int &position) {
   if(rates_total < 2 * settings.Lookback + 1) return false;

   for(int i = MathMin(rates_total - settings.Lookback - 1, settings.MaxCandles - settings.Lookback - 1); i >= settings.Lookback; i--) {
      bool isValleyCandidate = true;
      if(settings.DetectionMethod != METHOD_ZIGZAG && settings.DetectionMethod != METHOD_BREAK_OF_STRUCTURE && settings.DetectionMethod != METHOD_MARKET_STRUCTURE_SHIFT) {
         for(int j = 1; j <= settings.Lookback; j++) {
            if(i - j >= 0 && low[i] >= low[i - j]) isValleyCandidate = false;
            if(i + j < rates_total && low[i] >= low[i + j]) isValleyCandidate = false;
         }
      }
      bool isFinalValley = false;
      switch(settings.DetectionMethod) {
         case METHOD_SIMPLE:
            isFinalValley = isValleyCandidate;
            break;
         case METHOD_SEQUENTIAL:
            isFinalValley = IsSequential(i, false);
            break;
         case METHOD_POWER_SWING:
            isFinalValley = HasEnoughPower(i, false, low[i], time[i]);
            break;
         case METHOD_ZIGZAG:
            isFinalValley = IsZigZag(i, false);
            break;
         case METHOD_BREAK_OF_STRUCTURE:
            bool dummy;
            IdentifySwingPoints(i, dummy, isFinalValley);
            break;
         case METHOD_MARKET_STRUCTURE_SHIFT:
            IdentifyMSS(i, dummy, isFinalValley);
            break;
      }
      if(isFinalValley) {
         price = low[i];
         time = time[i];
         position = i;
         lastConfirmedValley.price = price;
         lastConfirmedValley.time = time;
         lastConfirmedValley.position = position;
         return true;
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| تابع پیدا کردن قله (از Fineflow)                                |
//+------------------------------------------------------------------+
bool CHipoFibonacci::FindPeak(datetime &time, double &price, int &position) {
   if(rates_total < 2 * settings.Lookback + 1) return false;

   for(int i = MathMin(rates_total - settings.Lookback - 1, settings.MaxCandles - settings.Lookback - 1); i >= settings.Lookback; i--) {
      bool isPeakCandidate = true;
      if(settings.DetectionMethod != METHOD_ZIGZAG && settings.DetectionMethod != METHOD_BREAK_OF_STRUCTURE && settings.DetectionMethod != METHOD_MARKET_STRUCTURE_SHIFT) {
         for(int j = 1; j <= settings.Lookback; j++) {
            if(i - j >= 0 && high[i] <= high[i - j]) isPeakCandidate = false;
            if(i + j < rates_total && high[i] <= high[i + j]) isPeakCandidate = false;
         }
      }
      bool isFinalPeak = false;
      switch(settings.DetectionMethod) {
         case METHOD_SIMPLE:
            isFinalPeak = isPeakCandidate;
            break;
         case METHOD_SEQUENTIAL:
            isFinalPeak = IsSequential(i, true);
            break;
         case METHOD_POWER_SWING:
            isFinalPeak = HasEnoughPower(i, true, high[i], time[i]);
            break;
         case METHOD_ZIGZAG:
            isFinalPeak = IsZigZag(i, true);
            break;
         case METHOD_BREAK_OF_STRUCTURE:
            bool dummy;
            IdentifySwingPoints(i, isFinalPeak, dummy);
            break;
         case METHOD_MARKET_STRUCTURE_SHIFT:
            IdentifyMSS(i, isFinalPeak, dummy);
            break;
      }
      if(isFinalPeak) {
         price = high[i];
         time = time[i];
         position = i;
         lastConfirmedPeak.price = price;
         lastConfirmedPeak.time = time;
         lastConfirmedPeak.position = position;
         return true;
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| توابع کمکی Fineflow                                             |
//+------------------------------------------------------------------+
bool CHipoFibonacci::IsSequential(int i, bool isPeak) {
   if(i + settings.SequentialLookback >= rates_total) return false;

   if(settings.UseStrictSequential) {
      switch(settings.SequentialCriterion) {
         case CRITERION_HIGH:
            return CheckSequential(i, isPeak, high);
         case CRITERION_LOW:
            return CheckSequential(i, isPeak, low);
         case CRITERION_OPEN:
            return CheckSequential(i, isPeak, open);
         case CRITERION_CLOSE:
            return CheckSequential(i, isPeak, close);
      }
   } else {
      if(CheckSequential(i, isPeak, high)) return true;
      if(CheckSequential(i, isPeak, low)) return true;
      if(CheckSequential(i, isPeak, open)) return true;
      if(CheckSequential(i, isPeak, close)) return true;
   }
   return false;
}

bool CHipoFibonacci::CheckSequential(int i, bool isPeak, const double &values[]) {
   if(isPeak) {
      for(int k = 1; k <= settings.SequentialLookback; k++) {
         if(i - k >= 0) {
            if(values[i - k] >= values[i - k + 1]) return false;
         } else return false;
         if(i + k < rates_total) {
            if(values[i + k] > values[i + k - 1]) return false;
         } else return false;
      }
      return true;
   } else {
      for(int k = 1; k <= settings.SequentialLookback; k++) {
         if(i - k >= 0) {
            if(values[i - k] <= values[i - k + 1]) return false;
         } else return false;
         if(i + k < rates_total) {
            if(values[i + k] < values[i + k - 1]) return false;
         } else return false;
      }
      return true;
   }
}

bool CHipoFibonacci::HasEnoughPower(int i, bool isPeak, double price, datetime time) {
   if(isPeak) {
      if(lastConfirmedValley.price > 0 && time > lastConfirmedValley.time) {
         double distance = price - lastConfirmedValley.price;
         if(distance > settings.AtrMultiplier * atrBuffer[i]) {
            if(settings.Enable_Logging) Print("قله تأیید شد - فاصله: ", distance, " > ", settings.AtrMultiplier * atrBuffer[i]);
            return true;
         }
      } else {
         return true;
      }
   } else {
      if(lastConfirmedPeak.price > 0 && time > lastConfirmedPeak.time) {
         double distance = lastConfirmedPeak.price - price;
         if(distance > settings.AtrMultiplier * atrBuffer[i]) {
            if(settings.Enable_Logging) Print("دره تأیید شد - فاصله: ", distance, " > ", settings.AtrMultiplier * atrBuffer[i]);
            return true;
         }
      } else {
         return true;
      }
   }
   return false;
}

bool CHipoFibonacci::IsZigZag(int i, bool isPeak) {
   if(i + settings.ZigZagDepth >= rates_total) return false;

   if(isPeak) {
      if(lastConfirmedValley.price > 0 && time[i] > lastConfirmedValley.time) {
         double distance = high[i] - lastConfirmedValley.price;
         if(distance > settings.ZigZagDeviation * _Point && i - lastConfirmedValley.position >= settings.ZigZagDepth) {
            if(settings.Enable_Logging) Print("قله زیگزاگ تأیید شد - فاصله: ", distance, " کندل‌ها: ", i - lastConfirmedValley.position);
            return true;
         }
      } else {
         return true;
      }
   } else {
      if(lastConfirmedPeak.price > 0 && time[i] > lastConfirmedPeak.time) {
         double distance = lastConfirmedPeak.price - low[i];
         if(distance > settings.ZigZagDeviation * _Point && i - lastConfirmedPeak.position >= settings.ZigZagDepth) {
            if(settings.Enable_Logging) Print("دره زیگزاگ تأیید شد - فاصله: ", distance, " کندل‌ها: ", i - lastConfirmedValley.position);
            return true;
         }
      } else {
         return true;
      }
   }
   return false;
}

void CHipoFibonacci::IdentifySwingPoints(int i, bool &isSwingHigh, bool &isSwingLow) {
   if(i + settings.Lookback >= rates_total) return;

   isSwingHigh = true;
   isSwingLow = true;

   for(int j = 1; j <= settings.Lookback; j++) {
      if(i - j >= 0 && high[i] <= high[i - j]) isSwingHigh = false;
      if(i + j < rates_total && high[i] <= high[i + j]) isSwingHigh = false;
      if(i - j >= 0 && low[i] >= low[i - j]) isSwingLow = false;
      if(i + j < rates_total && low[i] >= low[i + j]) isSwingLow = false;
   }

   if(isSwingHigh) {
      UpdateSwingArray(swingHighs_Array, swingHighs_Time, high[i], time[i]);
      if(settings.Enable_Logging) Print("سقف سوینگ در کندل ", i, " با قیمت ", high[i]);
   }
   if(isSwingLow) {
      UpdateSwingArray(swingLows_Array, swingLows_Time, low[i], time[i]);
      if(settings.Enable_Logging) Print("کف سوینگ در کندل ", i, " با قیمت ", low[i]);
   }
}

void CHipoFibonacci::IdentifyMSS(int i, bool &isFinalPeak, bool &isFinalValley) {
   if(i + settings.Lookback >= rates_total) return;

   bool isSwingHigh = true;
   bool isSwingLow = true;

   for(int j = 1; j <= settings.Lookback; j++) {
      if(i - j >= 0 && high[i] <= high[i - j]) isSwingHigh = false;
      if(i + j < rates_total && high[i] <= high[i + j]) isSwingHigh = false;
      if(i - j >= 0 && low[i] >= low[i - j]) isSwingLow = false;
      if(i + j < rates_total && low[i] >= low[i + j]) isSwingLow = false;
   }

   if(isSwingHigh) {
      UpdateSwingArray(swingHighs_Array, swingHighs_Time, high[i], time[i]);
      if(settings.Enable_Logging) Print("سقف سوینگ در کندل ", i, " با قیمت ", high[i]);
   }
   if(isSwingLow) {
      UpdateSwingArray(swingLows_Array, swingLows_Time, low[i], time[i]);
      if(settings.Enable_Logging) Print("کف سوینگ در کندل ", i, " با قیمت ", low[i]);
   }

   if(isSwingHigh && ArraySize(swingHighs_Array) >= 2 && ArraySize(swingLows_Array) >= 2) {
      if(swingHighs_Array[1] > swingHighs_Array[0] && swingLows_Array[1] > swingLows_Array[0]) {
         isFinalPeak = true;
         if(settings.Enable_Logging) Print("MSS صعودی در کندل ", i, " با سقف ", high[i]);
      }
   }

   if(isSwingLow && ArraySize(swingHighs_Array) >= 2 && ArraySize(swingLows_Array) >= 2) {
      if(swingHighs_Array[1] < swingHighs_Array[0] && swingLows_Array[1] < swingLows_Array[0]) {
         isFinalValley = true;
         if(settings.Enable_Logging) Print("MSS نزولی در کندل ", i, " با کف ", low[i]);
      }
   }
}

void CHipoFibonacci::UpdateSwingArray(double &array[], datetime &timeArray[], double price, datetime time) {
   int size = ArraySize(array);
   if(size < 2) {
      ArrayResize(array, size + 1);
      ArrayResize(timeArray, size + 1);
      array[size] = price;
      timeArray[size] = time;
   } else {
      ArrayRemove(array, 0, 1);
      ArrayRemove(timeArray, 0, 1);
      ArrayResize(array, 2);
      ArrayResize(timeArray, 2);
      array[1] = price;
      timeArray[1] = time;
   }
}

//+------------------------------------------------------------------+
//| توابع گرافیکی و محاسباتی                                       |
//+------------------------------------------------------------------+
void CHipoFibonacci::CreateStatusPanel() {
   ObjectCreate(0, "HipoFibonacci_Panel", OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, "HipoFibonacci_Panel", OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(0, "HipoFibonacci_Panel", OBJPROP_YDISTANCE, 10);
   ObjectSetInteger(0, "HipoFibonacci_Panel", OBJPROP_ZORDER, 0);
   ObjectSetInteger(0, "HipoFibonacci_Panel", OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, "HipoFibonacci_Panel", OBJPROP_FONTSIZE, 10);
   ObjectSetString(0, "HipoFibonacci_Panel", OBJPROP_FONT, "Arial");
   UpdateStatusPanel();
}

void CHipoFibonacci::UpdateStatusPanel() {
   if(!settings.Enable_Status_Panel) return;
   string statusText = "HipoFibonacci Library\n";
   statusText += "وضعیت: ";
   switch(currentStatus) {
      case WAITING_FOR_COMMAND: statusText += "منتظر دستور"; break;
      case SEARCHING_FOR_ANCHOR_LOW: statusText += "جستجوی کف لنگرگاه"; break;
      case SEARCHING_FOR_ANCHOR_HIGH: statusText += "جستجوی سقف لنگرگاه"; break;
      case MONITORING_SCENARIO_1_PROGRESS: statusText += "پایش سناریو ۱"; break;
      case SCENARIO_1_AWAITING_PULLBACK: statusText += "سناریو ۱ - انتظار پولبک"; break;
      case SCENARIO_1_AWAITING_BREAKOUT: statusText += "سناریو ۱ - انتظار شکست"; break;
      case SCENARIO_1_CONFIRMED_AWAITING_ENTRY: statusText += "سناریو ۱ - انتظار ورود"; break;
      case SCENARIO_2_ACTIVE_TARGETING_EXTENSION: statusText += "پایش سناریو ۲"; break;
      case SCENARIO_2_CONFIRMED_AWAITING_ENTRY: statusText += "سناریو ۲ - انتظار ورود"; break;
      case ENTRY_ZONE_ACTIVE: statusText += "ناحیه طلایی فعال"; break;
   }
   statusText += "\nدستور: ";
   color textColor = clrGray;
   switch(signalType) {
      case SIGNAL_BUY: statusText += "خرید"; textColor = clrGreen; break;
      case SIGNAL_SELL: statusText += "فروش"; textColor = clrRed; break;
      case STOP_SEARCH: statusText += "توقف"; textColor = clrGray; break;
   }
   ObjectSetString(0, "HipoFibonacci_Panel", OBJPROP_TEXT, statusText);
   ObjectSetInteger(0, "HipoFibonacci_Panel", OBJPROP_COLOR, textColor);
}

void CHipoFibonacci::DrawFibo(E_FiboType type, double price1, double price2, datetime time1, datetime time2, color clr, string scenario = "") {
   string name = "HipoFibo_" + EnumToString(type) + "_" + TimeToString(anchorID);
   if(scenario != "") name += "_" + scenario;
   ObjectCreate(0, name, OBJ_FIBO, 0, time1, price1, time2, price2);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false);
   ObjectSetString(0, name, OBJPROP_TEXT, scenario != "" ? scenario : EnumToString(type));
   for(int i = 0; i < settings.FibonacciLevelsCount; i++) {
      ObjectSetDouble(0, name, OBJPROP_LEVELVALUE, i, settings.FibonacciLevels[i] / 100.0);
      ObjectSetString(0, name, OBJPROP_LEVELTEXT, i, DoubleToString(settings.FibonacciLevels[i], 1) + "%");
   }
   ObjectSetInteger(0, name, OBJPROP_LEVELS, settings.FibonacciLevelsCount);
}

void CHipoFibonacci::DeleteFiboObjects() {
   string prefix = "HipoFibo_" + TimeToString(anchorID);
   for(int i = ObjectsTotal(0, 0, -1) - 1; i >= 0; i--) {
      string name = ObjectName(0, i);
      if(StringFind(name, prefix) >= 0) {
         ObjectDelete(0, name);
      }
   }
}

double CHipoFibonacci::CalculateFiboLevelPrice(E_FiboType type, double level) {
   double price1 = 0, price2 = 0;
   if(type == FIBO_MOTHER && mother.price != 0) {
      price1 = anchor.price;
      price2 = mother.price;
   } else if(type == FIBO_INTERMEDIATE && temporary.price != 0) {
      price1 = anchor.price;
      price2 = temporary.price;
   } else if(type == FIBO_FINAL && final.price != 0) {
      price1 = anchor.price;
      price2 = final.price;
   } else {
      return 0;
   }
   double levelValue = level / 100.0;
   if(signalType == SIGNAL_BUY) {
      return price1 + (price2 - price1) * levelValue;
   } else {
      return price1 - (price1 - price2) * levelValue;
   }
}
