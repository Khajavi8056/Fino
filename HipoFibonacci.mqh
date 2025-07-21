//+------------------------------------------------------------------+
//| HipoFibonacci.mqh                                                |
//| Copyright © 2025 HipoAlgorithm                                   |
//| https://hipoalgorithm.com                                        |
//| نسخه: 3.1                                                        |
//| توضیحات: کتابخانه مدیریت فیبوناچی با منطق لنگرگاه دینامیک و پشتیبانی از تایم‌فریم‌های چندگانه. |
//+------------------------------------------------------------------+

#property copyright "HipoAlgorithm"
#property link      "https://hipoalgorithm.com"
#property version   "3.1"
#property strict

//+------------------------------------------------------------------+
//| تعریف انوم‌ها (Enums)                                            |
//+------------------------------------------------------------------+

enum E_SignalType {
   SIGNAL_BUY,          // سیگنال خرید
   SIGNAL_SELL,         // سیگنال فروش
   STOP_SEARCH          // توقف جستجو
};

enum E_Status {
   WAITING_FOR_COMMAND,            // منتظر دریافت دستور
   SEARCHING_FOR_LEG,              // جستجوی لگ حرکتی
   SEARCHING_FOR_ANCHOR_DYNAMIC,   // در جستجوی لنگرگاه دینامیک
   MONITORING_SCENARIO_1_PROGRESS, // پایش پیشرفت سناریو 1
   SCENARIO_1_AWAITING_BREAKOUT,   // سناریو 1 - انتظار برای شکست
   SCENARIO_1_CONFIRMED_AWAITING_ENTRY, // سناریو 1 - انتظار برای ورود تأیید شده
   SCENARIO_2_ACTIVE_TARGETING_EXTENSION, // پایش سناریو 2 و هدف‌گذاری اکستنشن
   SCENARIO_2_CONFIRMED_AWAITING_ENTRY,  // سناریو 2 - انتظار برای ورود تأیید شده
   ENTRY_ZONE_ACTIVE                 // ناحیه ورود فعال
};

enum E_FiboType {
   FIBO_MOTHER,        // سطح فیبوناچی مادر
   FIBO_INTERMEDIATE,  // سطح فیبوناچی میانی
   FIBO_FINAL          // سطح فیبوناچی نهایی
};

//+------------------------------------------------------------------+
//| تعریف ساختارها (Structures)                                       |
//+------------------------------------------------------------------+

struct PeakValley {
   double price;    // قیمت نقطه
   datetime time;   // زمان نقطه
   int position;    // موقعیت در آرایه
};

struct HipoSettings {
   ENUM_TIMEFRAMES CalculationTimeframe; // تایم‌فریم محاسبات
   bool Enable_Drawing;                  // فعال‌سازی رسم
   bool Enable_Logging;                  // فعال‌سازی لاگ
   bool Enable_Status_Panel;             // فعال‌سازی پنل وضعیت
   int MaxCandles;                       // حداکثر تعداد کندل‌ها
   double MarginPips;                    // حاشیه به پیپ
   int SearchWindow;                     // بازه نگاه به عقب برای قله/دره
   int Fractal_Lookback;                 // تعداد کندل‌های سمت چپ و راست برای فراکتال
   double Min_Leg_Size_Pips;             // حداقل اندازه لگ به پیپ
   double EntryZone_LowerLevel;          // سطح پایین ناحیه ورود
   double EntryZone_UpperLevel;          // سطح بالا ناحیه ورود
   double ExtensionZone_LowerLevel;      // سطح پایین ناحیه اکستنشن
   double ExtensionZone_UpperLevel;      // سطح بالا ناحیه اکستنشن
   double FibonacciLevels[10];           // سطوح فیبوناچی
   int FibonacciLevelsCount;             // تعداد سطوح فیبوناچی
   color MotherFibo_Color;               // رنگ فیبوناچی مادر
   color IntermediateFibo_Color;         // رنگ فیبوناچی میانی
   color BuyEntryFibo_Color;             // رنگ ناحیه ورود خرید
   color SellEntryFibo_Color;            // رنگ ناحیه ورود فروش
};

//+------------------------------------------------------------------+
//| کلاس CHipoFibonacci                                              |
//+------------------------------------------------------------------+

class CHipoFibonacci {
private:
   HipoSettings settings;
   E_SignalType signalType;
   E_Status currentStatus;
   datetime anchorID;
   PeakValley anchor, mother, temporary, finalPoint;
   datetime entryZoneActivationTime;
   string finalFiboScenario;
   bool isEntryZoneActive;
   bool isInFocusMode;
   bool isAnchorLocked;
   double high[], low[], open[], close[];
   datetime time[];
   int rates_total;

   void ResetState();
   bool FindHipoLeg(PeakValley &mother_out);
   void CreateStatusPanel();
   void UpdateStatusPanel();
   void DrawFibo(E_FiboType type, double price1, double price2, datetime time1, datetime time2, color clr, string scenario = "");
   void DrawLegPoints();
   void DeleteFiboObjects();
   void DeleteLegPoints();
   double CalculateFiboLevelPrice(E_FiboType type, double level);
   void ProcessBuyLogic();
   void ProcessSellLogic();
   void CleanOldObjects(int max_candles);

public:
   CHipoFibonacci();
   ~CHipoFibonacci();

   void Init(HipoSettings &inputSettings);
   void ReceiveCommand(E_SignalType type, ENUM_TIMEFRAMES timeframe);
   void OnNewCandle(const MqlRates &rates[]);
   void OnTradePerformed();
   bool IsEntryZoneActive() { return isEntryZoneActive; }
   datetime GetEntryZoneActivationTime() { return entryZoneActivationTime; }
   string GetFinalFiboScenario() { return finalFiboScenario; }
   E_Status GetCurrentStatus() { return currentStatus; }
   double GetFiboLevelPrice(E_FiboType type, double level) { return CalculateFiboLevelPrice(type, level); }
};

//+------------------------------------------------------------------+
//| سازنده (Constructor)                                             |
//+------------------------------------------------------------------+

CHipoFibonacci::CHipoFibonacci() {
   ResetState();
}

//+------------------------------------------------------------------+
//| نابودگر (Destructor)                                             |
//+------------------------------------------------------------------+

CHipoFibonacci::~CHipoFibonacci() {
   ResetState();
   ObjectDelete(0, "HipoFibonacci_Panel_BG");
   ObjectDelete(0, "HipoFibonacci_Panel_Title");
   ObjectDelete(0, "HipoFibonacci_Panel_Separator");
   ObjectDelete(0, "HipoFibonacci_Panel_Status");
   ObjectDelete(0, "HipoFibonacci_Panel_Signal");
}

//+------------------------------------------------------------------+
//| تنظیم اولیه (Initialization)                                     |
//+------------------------------------------------------------------+

void CHipoFibonacci::Init(HipoSettings &inputSettings) {
   settings.CalculationTimeframe = inputSettings.CalculationTimeframe == 0 ? PERIOD_M5 : inputSettings.CalculationTimeframe;
   settings.Enable_Drawing = inputSettings.Enable_Drawing;
   settings.Enable_Logging = inputSettings.Enable_Logging;
   settings.Enable_Status_Panel = inputSettings.Enable_Status_Panel;
   settings.MaxCandles = inputSettings.MaxCandles > 0 ? inputSettings.MaxCandles : 500;
   settings.MarginPips = inputSettings.MarginPips > 0 ? inputSettings.MarginPips : 1.0;
   settings.SearchWindow = inputSettings.SearchWindow > 0 ? inputSettings.SearchWindow : 200;
   settings.Fractal_Lookback = inputSettings.Fractal_Lookback > 0 ? inputSettings.Fractal_Lookback : 5;
   settings.Min_Leg_Size_Pips = inputSettings.Min_Leg_Size_Pips > 0 ? inputSettings.Min_Leg_Size_Pips : 15.0;

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

   settings.MotherFibo_Color = inputSettings.MotherFibo_Color == clrNONE ? clrGray : inputSettings.MotherFibo_Color;
   settings.IntermediateFibo_Color = inputSettings.IntermediateFibo_Color == clrNONE ? clrLemonChiffon : inputSettings.IntermediateFibo_Color;
   settings.BuyEntryFibo_Color = inputSettings.BuyEntryFibo_Color == clrNONE ? clrLightGreen : inputSettings.BuyEntryFibo_Color;
   settings.SellEntryFibo_Color = inputSettings.SellEntryFibo_Color == clrNONE ? clrRed : inputSettings.SellEntryFibo_Color;

   if(settings.Enable_Status_Panel) CreateStatusPanel();
}

//+------------------------------------------------------------------+
//| دریافت دستور (Receive Command)                                   |
//+------------------------------------------------------------------+

void CHipoFibonacci::ReceiveCommand(E_SignalType type, ENUM_TIMEFRAMES timeframe) {
   if(isInFocusMode && type != STOP_SEARCH) {
      if(settings.Enable_Logging) Print("[HipoFibo] دستور جدید به دلیل حالت فوکوس نادیده گرفته شد.");
      return;
   }

   ResetState();
   if(type != STOP_SEARCH) {
      signalType = type;
      settings.CalculationTimeframe = timeframe == 0 ? PERIOD_M5 : timeframe;
      currentStatus = SEARCHING_FOR_LEG;
      if(settings.Enable_Logging) Print("دریافت دستور ", EnumToString(type), " در تایم‌فریم ", EnumToString(timeframe));
   }
   UpdateStatusPanel();
}

//+------------------------------------------------------------------+
//| پردازش کندل جدید (OnNewCandle)                                   |
//+------------------------------------------------------------------+

void CHipoFibonacci::OnNewCandle(const MqlRates &rates[]) {
   if(currentStatus == WAITING_FOR_COMMAND) return;

   rates_total = ArraySize(rates);
   if(rates_total == 0) return;

   ArrayResize(high, rates_total);
   ArrayResize(low, rates_total);
   ArrayResize(open, rates_total);
   ArrayResize(close, rates_total);
   ArrayResize(time, rates_total);

   for(int i = 0; i < rates_total; i++) {
      time[i] = rates[i].time;
      open[i] = rates[i].open;
      high[i] = rates[i].high;
      low[i] = rates[i].low;
      close[i] = rates[i].close;
   }

   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(open, true);
   ArraySetAsSeries(close, true);
   ArraySetAsSeries(time, true);

   CleanOldObjects(300);
   if(signalType == SIGNAL_BUY) ProcessBuyLogic();
   else if(signalType == SIGNAL_SELL) ProcessSellLogic();

   UpdateStatusPanel();
}

//+------------------------------------------------------------------+
//| پردازش بعد از معامله (OnTradePerformed)                          |
//+------------------------------------------------------------------+

void CHipoFibonacci::OnTradePerformed() {
   if(isEntryZoneActive) {
      ResetState();
      if(settings.Enable_Logging) Print("معامله انجام شد، ساختار ریست شد.");
   }
}

//+------------------------------------------------------------------+
//| یافتن لگ حرکتی (FindHipoLeg)                                    |
//+------------------------------------------------------------------+

bool CHipoFibonacci::FindHipoLeg(PeakValley &mother_out) {
   int required_candles = settings.SearchWindow + 2 * settings.Fractal_Lookback + 1;
   if(rates_total < required_candles) {
      if(settings.Enable_Logging) Print("[HipoFibo] تعداد کندل‌های کافی برای یافتن لگ وجود ندارد. نیاز: ", required_candles, "، موجود: ", rates_total);
      return false;
   }

   if(signalType == SIGNAL_BUY) {
      int mother_index = -1;
      for(int i = 1 + settings.Fractal_Lookback; i < settings.SearchWindow + settings.Fractal_Lookback && i < rates_total - settings.Fractal_Lookback; i++) {
         bool is_fractal = true;
         for(int j = 1; j <= settings.Fractal_Lookback; j++) {
            if(high[i] <= high[i - j] || high[i] <= high[i + j]) {
               is_fractal = false;
               break;
            }
         }
         if(is_fractal) {
            mother_index = i;
            break; // جدیدترین قله فراکتالی را انتخاب می‌کنیم
         }
      }
      if(mother_index == -1) {
         if(settings.Enable_Logging) Print("[HipoFibo] قله فراکتالی یافت نشد در بازه ", settings.SearchWindow, " کندل.");
         return false;
      }

      mother_out.price = high[mother_index];
      mother_out.time = time[mother_index];
      mother_out.position = mother_index;

      if(settings.Enable_Logging) Print("[HipoFibo] قله فراکتالی یافت شد: قیمت ", mother_out.price, ", زمان ", TimeToString(mother_out.time), ", ایندکس ", mother_out.position);
      return true;
   } else if(signalType == SIGNAL_SELL) {
      int mother_index = -1;
      for(int i = 1 + settings.Fractal_Lookback; i < settings.SearchWindow + settings.Fractal_Lookback && i < rates_total - settings.Fractal_Lookback; i++) {
         bool is_fractal = true;
         for(int j = 1; j <= settings.Fractal_Lookback; j++) {
            if(low[i] >= low[i - j] || low[i] >= low[i + j]) {
               is_fractal = false;
               break;
            }
         }
         if(is_fractal) {
            mother_index = i;
            break; // جدیدترین دره فراکتالی را انتخاب می‌کنیم
         }
      }
      if(mother_index == -1) {
         if(settings.Enable_Logging) Print("[HipoFibo] دره فراکتالی یافت نشد در بازه ", settings.SearchWindow, " کندل.");
         return false;
      }

      mother_out.price = low[mother_index];
      mother_out.time = time[mother_index];
      mother_out.position = mother_index;

      if(settings.Enable_Logging) Print("[HipoFibo] دره فراکتالی یافت شد: قیمت ", mother_out.price, ", زمان ", TimeToString(mother_out.time), ", ایندکس ", mother_out.position);
      return true;
   }

   return false;
}

//+------------------------------------------------------------------+
//| پردازش منطق خرید (نسخه نهایی با پیاده‌سازی صحیح لنگرگاه دینامیک)   |
//+------------------------------------------------------------------+
void CHipoFibonacci::ProcessBuyLogic() {
   // --- فاز ۱: جستجوی لگ و یافتن Mother ---
   if(currentStatus == SEARCHING_FOR_LEG && !isInFocusMode) {
      PeakValley localMother;
      if(FindHipoLeg(localMother)) {
         mother = localMother;
         
         // یافتن Anchor اولیه (کمترین قیمت از مادر تا کندل فعلی)
         int anchor_index = ArrayMinimum(low, 1, mother.position);
         if(anchor_index == -1) { 
            if(settings.Enable_Logging) Print("[HipoFibo] کف لنگرگاه یافت نشد.");
            ResetState(); 
            return; 
         }

         anchor.price = low[anchor_index];
         anchor.time = time[anchor_index];
         anchor.position = anchor_index;
         
         anchorID = anchor.time;

         double leg_size = (mother.price - anchor.price) / _Point;
         if(leg_size < settings.Min_Leg_Size_Pips) {
            if(settings.Enable_Logging) Print("[HipoFibo] لگ اولیه خیلی کوچک است: ", leg_size, " پیپ.");
            ResetState();
            return;
         }

         isInFocusMode = true;
         isAnchorLocked = false;
         currentStatus = SEARCHING_FOR_ANCHOR_DYNAMIC;
         if(settings.Enable_Drawing) {
            DeleteFiboObjects();
            DeleteLegPoints();
            DrawFibo(FIBO_MOTHER, anchor.price, mother.price, anchor.time, mother.time, settings.MotherFibo_Color);
            DrawLegPoints();
         }
         if(settings.Enable_Logging) Print("مادر یافت شد. ورود به فاز لنگرگاه دینامیک. لنگرگاه اولیه: ", anchor.price);
      }
   }
   // --- فاز ۲: جستجوی شناور برای لنگرگاه نهایی ---
   else if(currentStatus == SEARCHING_FOR_ANCHOR_DYNAMIC) {
      if(settings.Enable_Drawing) {
         DeleteFiboObjects();
         DeleteLegPoints();
      }

      if(!isAnchorLocked) {
         int new_anchor_index = ArrayMinimum(low, 1, mother.position);
         if(new_anchor_index != -1 && low[new_anchor_index] < anchor.price) {
            anchor.price = low[new_anchor_index];
            anchor.time = time[new_anchor_index];
            anchor.position = new_anchor_index;
            if(settings.Enable_Logging) Print("لنگرگاه دینامیک آپدیت شد: ", anchor.price);
         }
      }

      double leg_size = (mother.price - anchor.price) / _Point;
      if(leg_size < settings.Min_Leg_Size_Pips) {
         if(settings.Enable_Logging) Print("[HipoFibo] لگ خیلی کوچک است: ", leg_size, " پیپ.");
         ResetState();
         return;
      }

      if(settings.Enable_Drawing) {
         DrawFibo(FIBO_MOTHER, anchor.price, mother.price, anchor.time, mother.time, settings.MotherFibo_Color);
         DrawLegPoints();
      }

      if(high[1] > mother.price) {
         if(settings.Enable_Logging) Print("ابطال ساختار: قیمت از Mother_High عبور کرد.");
         ResetState();
         return;
      }

      double fibo_50_level = CalculateFiboLevelPrice(FIBO_MOTHER, 50.0);
      if(high[1] >= fibo_50_level && !isAnchorLocked) {
         isAnchorLocked = true;
         if(settings.Enable_Logging) Print("لنگرگاه در قیمت ", anchor.price, " قفل شد. ورود به فاز پایش.");
         currentStatus = MONITORING_SCENARIO_1_PROGRESS;
         return;
      }
   }
   // --- فاز ۳: پایش سناریو ۱ (بعد از قفل شدن لنگرگاه) ---
   else if(currentStatus == MONITORING_SCENARIO_1_PROGRESS) {
      if(settings.Enable_Drawing) {
         ObjectDelete(0, "HipoFibo_INTERMEDIATE_" + TimeToString(anchorID));
         DrawFibo(FIBO_INTERMEDIATE, anchor.price, high[1], anchor.time, time[1], settings.IntermediateFibo_Color);
      }
      
      if(low[1] < anchor.price - settings.MarginPips * _Point) {
         if(settings.Enable_Logging) Print("شکست ساختار: لنگرگاه شکسته در قیمت ", low[1]);
         ResetState();
         return;
      }
      if(high[1] > mother.price) {
         currentStatus = SCENARIO_2_ACTIVE_TARGETING_EXTENSION;
         temporary.price = 0;
         temporary.time = 0;
         temporary.position = 0;
         finalPoint.price = 0;
         finalPoint.time = 0;
         finalPoint.position = 0;
         if(settings.Enable_Logging) Print("ورود به سناریو ۲: شکست Mother_High در ", high[1]);
         return;
      }
      if(high[1] > temporary.price) {
         temporary.price = high[1];
         temporary.time = time[1];
         temporary.position = 1;
      }
      double goldenZoneLow = CalculateFiboLevelPrice(FIBO_INTERMEDIATE, settings.EntryZone_LowerLevel);
      double goldenZoneHigh = CalculateFiboLevelPrice(FIBO_INTERMEDIATE, settings.EntryZone_UpperLevel);
      if(close[1] >= goldenZoneLow && close[1] <= goldenZoneHigh && temporary.price > 0) {
         currentStatus = SCENARIO_1_AWAITING_BREAKOUT;
         if(settings.Enable_Logging) Print("پولبک به ناحیه طلایی، انتظار شکست Temporary_High در ", temporary.price);
      }
   }
   // --- فاز ۴: انتظار شکست برای سناریو ۱ ---
   else if(currentStatus == SCENARIO_1_AWAITING_BREAKOUT) {
      if(low[1] < anchor.price - settings.MarginPips * _Point) {
         if(settings.Enable_Logging) Print("شکست ساختار: لنگرگاه شکسته در قیمت ", low[1]);
         ResetState();
         return;
      }
      if(high[1] > temporary.price) {
         if(settings.Enable_Drawing) {
            ObjectDelete(0, "HipoFibo_INTERMEDIATE_" + TimeToString(anchorID));
            DrawFibo(FIBO_FINAL, anchor.price, high[1], anchor.time, time[1], settings.BuyEntryFibo_Color, "Scenario1");
         }
         finalPoint.price = high[1];
         finalPoint.time = time[1];
         finalPoint.position = 1;
         finalFiboScenario = "Scenario1";
         currentStatus = SCENARIO_1_CONFIRMED_AWAITING_ENTRY;
         if(settings.Enable_Logging) Print("سناریو ۱ تأیید شد، Temporary_High شکسته شد.");
      }
   }
   // --- فاز ۵: انتظار ورود برای سناریو ۱ ---
   else if(currentStatus == SCENARIO_1_CONFIRMED_AWAITING_ENTRY) {
      if(low[1] < anchor.price - settings.MarginPips * _Point) {
         if(settings.Enable_Logging) Print("شکست ساختار: لنگرگاه شکسته در قیمت ", low[1]);
         ResetState();
         return;
      }
      double goldenZoneLow = CalculateFiboLevelPrice(FIBO_FINAL, settings.EntryZone_LowerLevel);
      double goldenZoneHigh = CalculateFiboLevelPrice(FIBO_FINAL, settings.EntryZone_UpperLevel);
      if(close[1] >= goldenZoneLow && close[1] <= goldenZoneHigh) {
         isEntryZoneActive = true;
         entryZoneActivationTime = time[1];
         currentStatus = ENTRY_ZONE_ACTIVE;
         if(settings.Enable_Logging) Print("ناحیه طلایی فعال در قیمت ", close[1], ", زمان ", TimeToString(time[1]));
      }
   }
   // --- فاز ۶: پایش سناریو ۲ و هدف‌گذاری اکستنشن ---
   else if(currentStatus == SCENARIO_2_ACTIVE_TARGETING_EXTENSION) {
      if(low[1] < anchor.price - settings.MarginPips * _Point) {
         if(settings.Enable_Logging) Print("شکست ساختار: لنگرگاه شکسته در قیمت ", low[1]);
         ResetState();
         return;
      }
      if(high[1] > CalculateFiboLevelPrice(FIBO_MOTHER, settings.ExtensionZone_UpperLevel)) {
         if(settings.Enable_Logging) Print("شکست ساختار: اکستنشن شکسته در قیمت ", high[1]);
         ResetState();
         return;
      }
      double extensionLow = CalculateFiboLevelPrice(FIBO_MOTHER, settings.ExtensionZone_LowerLevel);
      if(high[1] >= extensionLow) {
         if(high[1] > finalPoint.price) {
            finalPoint.price = high[1];
            finalPoint.time = time[1];
            finalPoint.position = 1;
            if(settings.Enable_Drawing) {
               ObjectDelete(0, "HipoFibo_INTERMEDIATE_" + TimeToString(anchorID));
               DrawFibo(FIBO_INTERMEDIATE, anchor.price, finalPoint.price, anchor.time, finalPoint.time, settings.IntermediateFibo_Color);
            }
            if(settings.Enable_Logging) Print("آپدیت سقف نهایی سناریو ۲ در قیمت ", finalPoint.price);
         }
         if(high[1] < finalPoint.price && finalPoint.price > 0) {
            if(settings.Enable_Drawing) {
               ObjectDelete(0, "HipoFibo_INTERMEDIATE_" + TimeToString(anchorID));
               DrawFibo(FIBO_FINAL, anchor.price, finalPoint.price, anchor.time, finalPoint.time, settings.BuyEntryFibo_Color, "Scenario2");
            }
            finalFiboScenario = "Scenario2";
            currentStatus = SCENARIO_2_CONFIRMED_AWAITING_ENTRY;
            if(settings.Enable_Logging) Print("سناریو ۲ تأیید شد، پولبک از سقف نهایی ", finalPoint.price, " شروع شد");
         }
      }
   }
   // --- فاز ۷: انتظار ورود برای سناریو ۲ ---
   else if(currentStatus == SCENARIO_2_CONFIRMED_AWAITING_ENTRY) {
      if(low[1] < anchor.price - settings.MarginPips * _Point) {
         if(settings.Enable_Logging) Print("شکست ساختار: لنگرگاه شکسته در قیمت ", low[1]);
         ResetState();
         return;
      }
      if(high[1] > CalculateFiboLevelPrice(FIBO_MOTHER, settings.ExtensionZone_UpperLevel)) {
         if(settings.Enable_Logging) Print("شکست ساختار: اکستنشن شکسته در قیمت ", high[1]);
         ResetState();
         return;
      }
      double goldenZoneLow = CalculateFiboLevelPrice(FIBO_FINAL, settings.EntryZone_LowerLevel);
      double goldenZoneHigh = CalculateFiboLevelPrice(FIBO_FINAL, settings.EntryZone_UpperLevel);
      if(close[1] >= goldenZoneLow && close[1] <= goldenZoneHigh) {
         isEntryZoneActive = true;
         entryZoneActivationTime = time[1];
         currentStatus = ENTRY_ZONE_ACTIVE;
         if(settings.Enable_Logging) Print("ناحیه طلایی فعال در قیمت ", close[1], ", زمان ", TimeToString(time[1]));
      }
   }
}

//+------------------------------------------------------------------+
//| پردازش منطق فروش (نسخه نهایی با پیاده‌سازی صحیح لنگرگاه دینامیک)    |
//+------------------------------------------------------------------+
void CHipoFibonacci::ProcessSellLogic() {
   // --- فاز ۱: جستجوی لگ و یافتن Mother ---
   if(currentStatus == SEARCHING_FOR_LEG && !isInFocusMode) {
      PeakValley localMother;
      if(FindHipoLeg(localMother)) {
         mother = localMother;
         
         int anchor_index = ArrayMaximum(high, 1, mother.position);
         if(anchor_index == -1) { 
            if(settings.Enable_Logging) Print("[HipoFibo] سقف لنگرگاه یافت نشد.");
            ResetState();
            return;
         }

         anchor.price = high[anchor_index];
         anchor.time = time[anchor_index];
         anchor.position = anchor_index;

         anchorID = anchor.time;

         double leg_size = (anchor.price - mother.price) / _Point;
         if(leg_size < settings.Min_Leg_Size_Pips) {
            if(settings.Enable_Logging) Print("[HipoFibo] لگ اولیه خیلی کوچک است: ", leg_size, " پیپ.");
            ResetState();
            return;
         }

         isInFocusMode = true;
         isAnchorLocked = false;
         currentStatus = SEARCHING_FOR_ANCHOR_DYNAMIC;
         if(settings.Enable_Drawing) {
            DeleteFiboObjects();
            DeleteLegPoints();
            DrawFibo(FIBO_MOTHER, anchor.price, mother.price, anchor.time, mother.time, settings.MotherFibo_Color);
            DrawLegPoints();
         }
         if(settings.Enable_Logging) Print("مادر یافت شد. ورود به فاز لنگرگاه دینامیک. لنگرگاه اولیه: ", anchor.price);
      }
   }
   // --- فاز ۲: جستجوی شناور برای لنگرگاه نهایی ---
   else if(currentStatus == SEARCHING_FOR_ANCHOR_DYNAMIC) {
      if(settings.Enable_Drawing) {
         DeleteFiboObjects();
         DeleteLegPoints();
      }

      if(!isAnchorLocked) {
         int new_anchor_index = ArrayMaximum(high, 1, mother.position);
         if(new_anchor_index != -1 && high[new_anchor_index] > anchor.price) {
            anchor.price = high[new_anchor_index];
            anchor.time = time[new_anchor_index];
            anchor.position = new_anchor_index;
            if(settings.Enable_Logging) Print("لنگرگاه دینامیک آپدیت شد: ", anchor.price);
         }
      }

      double leg_size = (anchor.price - mother.price) / _Point;
      if(leg_size < settings.Min_Leg_Size_Pips) {
         if(settings.Enable_Logging) Print("[HipoFibo] لگ خیلی کوچک است: ", leg_size, " پیپ.");
         ResetState();
         return;
      }

      if(settings.Enable_Drawing) {
         DrawFibo(FIBO_MOTHER, anchor.price, mother.price, anchor.time, mother.time, settings.MotherFibo_Color);
         DrawLegPoints();
      }

      if(low[1] < mother.price) {
         if(settings.Enable_Logging) Print("ابطال ساختار: قیمت از Mother_Low عبور کرد.");
         ResetState();
         return;
      }

      double fibo_50_level = CalculateFiboLevelPrice(FIBO_MOTHER, 50.0);
      if(low[1] <= fibo_50_level && !isAnchorLocked) {
         isAnchorLocked = true;
         if(settings.Enable_Logging) Print("لنگرگاه در قیمت ", anchor.price, " قفل شد. ورود به فاز پایش.");
         currentStatus = MONITORING_SCENARIO_1_PROGRESS;
         return;
      }
   }
   // --- فاز ۳: پایش سناریو ۱ (بعد از قفل شدن لنگرگاه) ---
   else if(currentStatus == MONITORING_SCENARIO_1_PROGRESS) {
      if(settings.Enable_Drawing) {
         ObjectDelete(0, "HipoFibo_INTERMEDIATE_" + TimeToString(anchorID));
         DrawFibo(FIBO_INTERMEDIATE, anchor.price, low[1], anchor.time, time[1], settings.IntermediateFibo_Color);
      }
      
      if(high[1] > anchor.price + settings.MarginPips * _Point) {
         if(settings.Enable_Logging) Print("شکست ساختار: لنگرگاه شکسته در قیمت ", high[1]);
         ResetState();
         return;
      }
      if(low[1] < mother.price) {
         currentStatus = SCENARIO_2_ACTIVE_TARGETING_EXTENSION;
         temporary.price = 0;
         temporary.time = 0;
         temporary.position = 0;
         finalPoint.price = 0;
         finalPoint.time = 0;
         finalPoint.position = 0;
         if(settings.Enable_Logging) Print("ورود به سناریو ۲: شکست Mother_Low در ", low[1]);
         return;
      }
      if(low[1] < temporary.price || temporary.price == 0) {
         temporary.price = low[1];
         temporary.time = time[1];
         temporary.position = 1;
      }
      double goldenZoneLow = CalculateFiboLevelPrice(FIBO_INTERMEDIATE, settings.EntryZone_LowerLevel);
      double goldenZoneHigh = CalculateFiboLevelPrice(FIBO_INTERMEDIATE, settings.EntryZone_UpperLevel);
      if(close[1] >= goldenZoneLow && close[1] <= goldenZoneHigh && temporary.price > 0) {
         currentStatus = SCENARIO_1_AWAITING_BREAKOUT;
         if(settings.Enable_Logging) Print("پولبک به ناحیه طلایی، انتظار شکست Temporary_Low در ", temporary.price);
      }
   }
   // --- فاز ۴: انتظار شکست برای سناریو ۱ ---
   else if(currentStatus == SCENARIO_1_AWAITING_BREAKOUT) {
      if(high[1] > anchor.price + settings.MarginPips * _Point) {
         if(settings.Enable_Logging) Print("شکست ساختار: لنگرگاه شکسته در قیمت ", high[1]);
         ResetState();
         return;
      }
      if(low[1] < temporary.price) {
         if(settings.Enable_Drawing) {
            ObjectDelete(0, "HipoFibo_INTERMEDIATE_" + TimeToString(anchorID));
            DrawFibo(FIBO_FINAL, anchor.price, low[1], anchor.time, time[1], settings.SellEntryFibo_Color, "Scenario1");
         }
         finalPoint.price = low[1];
         finalPoint.time = time[1];
         finalPoint.position = 1;
         finalFiboScenario = "Scenario1";
         currentStatus = SCENARIO_1_CONFIRMED_AWAITING_ENTRY;
         if(settings.Enable_Logging) Print("سناریو ۱ تأیید شد، Temporary_Low شکسته شد.");
      }
   }
   // --- فاز ۵: انتظار ورود برای سناریو ۱ ---
   else if(currentStatus == SCENARIO_1_CONFIRMED_AWAITING_ENTRY) {
      if(high[1] > anchor.price + settings.MarginPips * _Point) {
         if(settings.Enable_Logging) Print("شکست ساختار: لنگرگاه شکسته در قیمت ", high[1]);
         ResetState();
         return;
      }
      double goldenZoneLow = CalculateFiboLevelPrice(FIBO_FINAL, settings.EntryZone_LowerLevel);
      double goldenZoneHigh = CalculateFiboLevelPrice(FIBO_FINAL, settings.EntryZone_UpperLevel);
      if(close[1] >= goldenZoneLow && close[1] <= goldenZoneHigh) {
         isEntryZoneActive = true;
         entryZoneActivationTime = time[1];
         currentStatus = ENTRY_ZONE_ACTIVE;
         if(settings.Enable_Logging) Print("ناحیه طلایی فعال در قیمت ", close[1], ", زمان ", TimeToString(time[1]));
      }
   }
   // --- فاز ۶: پایش سناریو ۲ و هدف‌گذاری اکستنشن ---
   else if(currentStatus == SCENARIO_2_ACTIVE_TARGETING_EXTENSION) {
      if(high[1] > anchor.price + settings.MarginPips * _Point) {
         if(settings.Enable_Logging) Print("شکست ساختار: لنگرگاه شکسته در قیمت ", high[1]);
         ResetState();
         return;
      }
      if(low[1] < CalculateFiboLevelPrice(FIBO_MOTHER, settings.ExtensionZone_UpperLevel)) {
         if(settings.Enable_Logging) Print("شکست ساختار: اکستنشن شکسته در قیمت ", low[1]);
         ResetState();
         return;
      }
      double extensionHigh = CalculateFiboLevelPrice(FIBO_MOTHER, settings.ExtensionZone_LowerLevel);
      if(low[1] <= extensionHigh) {
         if(low[1] < finalPoint.price || finalPoint.price == 0) {
            finalPoint.price = low[1];
            finalPoint.time = time[1];
            finalPoint.position = 1;
            if(settings.Enable_Drawing) {
               ObjectDelete(0, "HipoFibo_INTERMEDIATE_" + TimeToString(anchorID));
               DrawFibo(FIBO_INTERMEDIATE, anchor.price, finalPoint.price, anchor.time, finalPoint.time, settings.IntermediateFibo_Color);
            }
            if(settings.Enable_Logging) Print("آپدیت کف نهایی سناریو ۲ در قیمت ", finalPoint.price);
         }
         if(low[1] > finalPoint.price && finalPoint.price > 0) {
            if(settings.Enable_Drawing) {
               ObjectDelete(0, "HipoFibo_INTERMEDIATE_" + TimeToString(anchorID));
               DrawFibo(FIBO_FINAL, anchor.price, finalPoint.price, anchor.time, finalPoint.time, settings.SellEntryFibo_Color, "Scenario2");
            }
            finalFiboScenario = "Scenario2";
            currentStatus = SCENARIO_2_CONFIRMED_AWAITING_ENTRY;
            if(settings.Enable_Logging) Print("سناریو ۲ تأیید شد، پولبک از کف نهایی ", finalPoint.price, " شروع شد");
         }
      }
   }
   // --- فاز ۷: انتظار ورود برای سناریو ۲ ---
   else if(currentStatus == SCENARIO_2_CONFIRMED_AWAITING_ENTRY) {
      if(high[1] > anchor.price + settings.MarginPips * _Point) {
         if(settings.Enable_Logging) Print("شکست ساختار: لنگرگاه شکسته در قیمت ", high[1]);
         ResetState();
         return;
      }
      if(low[1] < CalculateFiboLevelPrice(FIBO_MOTHER, settings.ExtensionZone_UpperLevel)) {
         if(settings.Enable_Logging) Print("شکست ساختار: اکستنشن شکسته در قیمت ", low[1]);
         ResetState();
         return;
      }
      double goldenZoneLow = CalculateFiboLevelPrice(FIBO_FINAL, settings.EntryZone_LowerLevel);
      double goldenZoneHigh = CalculateFiboLevelPrice(FIBO_FINAL, settings.EntryZone_UpperLevel);
      if(close[1] >= goldenZoneLow && close[1] <= goldenZoneHigh) {
         isEntryZoneActive = true;
         entryZoneActivationTime = time[1];
         currentStatus = ENTRY_ZONE_ACTIVE;
         if(settings.Enable_Logging) Print("ناحیه طلایی فعال در قیمت ", close[1], ", زمان ", TimeToString(time[1]));
      }
   }
}

//+------------------------------------------------------------------+
//| رسم نقاط لگ (DrawLegPoints)                                      |
//+------------------------------------------------------------------+

void CHipoFibonacci::DrawLegPoints() {
   string mother_name = "HipoPoint_Mother_" + TimeToString(anchorID);
   string anchor_name = "HipoPoint_Anchor_" + TimeToString(anchorID);
   double offset = 5.0 * _Point;

   ObjectCreate(0, mother_name, OBJ_ARROW, 0, mother.time, signalType == SIGNAL_BUY ? mother.price + offset : mother.price - offset);
   ObjectSetInteger(0, mother_name, OBJPROP_COLOR, signalType == SIGNAL_BUY ? clrGreen : clrRed);
   ObjectSetInteger(0, mother_name, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, mother_name, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, mother_name, OBJPROP_ARROWCODE, 108);
   ObjectSetString(0, mother_name, OBJPROP_TEXT, "Mother");

   ObjectCreate(0, anchor_name, OBJ_ARROW, 0, anchor.time, signalType == SIGNAL_BUY ? anchor.price - offset : anchor.price + offset);
   ObjectSetInteger(0, anchor_name, OBJPROP_COLOR, signalType == SIGNAL_BUY ? clrRed : clrGreen);
   ObjectSetInteger(0, anchor_name, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, anchor_name, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, anchor_name, OBJPROP_ARROWCODE, 108);
   ObjectSetString(0, anchor_name, OBJPROP_TEXT, "Anchor");
}

//+------------------------------------------------------------------+
//| حذف نقاط لگ (DeleteLegPoints)                                    |
//+------------------------------------------------------------------+

void CHipoFibonacci::DeleteLegPoints() {
   string prefix = "HipoPoint_" + TimeToString(anchorID);
   for(int i = ObjectsTotal(0, 0, -1) - 1; i >= 0; i--) {
      string name = ObjectName(0, i);
      if(StringFind(name, prefix) >= 0) ObjectDelete(0, name);
   }
}

//+------------------------------------------------------------------+
//| رسم فیبوناچی (DrawFibo)                                         |
//+------------------------------------------------------------------+

void CHipoFibonacci::DrawFibo(E_FiboType type, double price1, double price2, datetime time1, datetime time2, color clr, string scenario = "") {
   string name = "HipoFibo_" + EnumToString(type) + "_" + TimeToString(anchorID);
   if(scenario != "") name += "_" + scenario;

   // برای خرید: نقطه ۱۰۰٪ روی مادر (سقف، price2)، نقطه ۰٪ روی لنگرگاه (کف، price1)
   // برای فروش: نقطه ۱۰۰٪ روی مادر (کف، price2)، نقطه ۰٪ روی لنگرگاه (سقف، price1)
   double fibo_start_price = (signalType == SIGNAL_BUY) ? price2 : price1;
   double fibo_end_price = (signalType == SIGNAL_BUY) ? price1 : price2;
   datetime fibo_start_time = (signalType == SIGNAL_BUY) ? time2 : time1;
   datetime fibo_end_time = (signalType == SIGNAL_BUY) ? time1 : time2;

   if(!ObjectCreate(0, name, OBJ_FIBO, 0, fibo_start_time, fibo_start_price, fibo_end_time, fibo_end_price)) {
      ObjectSetInteger(0, name, OBJPROP_TIME, 0, fibo_start_time);
      ObjectSetDouble(0, name, OBJPROP_PRICE, 0, fibo_start_price);
      ObjectMove(0, name, 1, fibo_end_time, fibo_end_price);
   }

   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false);
   ObjectSetString(0, name, OBJPROP_TEXT, scenario != "" ? scenario : EnumToString(type));

   ObjectSetInteger(0, name, OBJPROP_LEVELS, settings.FibonacciLevelsCount);
   for(int i = 0; i < settings.FibonacciLevelsCount; i++) {
      ObjectSetDouble(0, name, OBJPROP_LEVELVALUE, i, settings.FibonacciLevels[i] / 100.0);
      ObjectSetString(0, name, OBJPROP_LEVELTEXT, i, DoubleToString(settings.FibonacciLevels[i], 1) + "%");
   }
}

//+------------------------------------------------------------------+
//| حذف اشیاء فیبوناچی (DeleteFiboObjects)                         |
//+------------------------------------------------------------------+

void CHipoFibonacci::DeleteFiboObjects() {
   string prefix = "HipoFibo_" + TimeToString(anchorID);
   for(int i = ObjectsTotal(0, 0, -1) - 1; i >= 0; i--) {
      string name = ObjectName(0, i);
      if(StringFind(name, prefix) >= 0) ObjectDelete(0, name);
   }
}

//+------------------------------------------------------------------+
//| محاسبه قیمت سطح فیبوناچی (CalculateFiboLevelPrice)              |
//+------------------------------------------------------------------+

double CHipoFibonacci::CalculateFiboLevelPrice(E_FiboType type, double level) {
   double price1 = 0, price2 = 0;
   if(type == FIBO_MOTHER && mother.price != 0) {
      price1 = anchor.price; // لنگرگاه
      price2 = mother.price; // مادر
   } else if(type == FIBO_INTERMEDIATE && temporary.price != 0) {
      price1 = anchor.price;
      price2 = temporary.price;
   } else if(type == FIBO_FINAL && finalPoint.price != 0) {
      price1 = anchor.price;
      price2 = finalPoint.price;
   } else {
      return 0;
   }

   double levelValue = level / 100.0;
   if(signalType == SIGNAL_BUY) {
      return price2 - (price2 - price1) * levelValue; // از مادر (سقف) به لنگرگاه (کف)
   } else {
      return price2 + (price1 - price2) * levelValue; // از مادر (کف) به لنگرگاه (سقف)
   }
}

//+------------------------------------------------------------------+
//| پاکسازی اشیاء قدیمی (CleanOldObjects)                           |
//+------------------------------------------------------------------+

void CHipoFibonacci::CleanOldObjects(int max_candles) {
   if(!settings.Enable_Drawing) return;
   for(int i = ObjectsTotal(0, 0, -1) - 1; i >= 0; i--) {
      string name = ObjectName(0, i);
      if(StringFind(name, "HipoFibo_") >= 0 || StringFind(name, "HipoPoint_") >= 0) {
         datetime obj_time = (datetime)ObjectGetInteger(0, name, OBJPROP_TIME);
         int bar_index = iBarShift(_Symbol, settings.CalculationTimeframe, obj_time);
         if(bar_index > max_candles) {
            ObjectDelete(0, name);
            if(settings.Enable_Logging) Print("پاکسازی آبجکت قدیمی: ", name, ", ایندکس: ", bar_index);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| تابع مرکزی برای ریست کردن (ResetState)                           |
//+------------------------------------------------------------------+

void CHipoFibonacci::ResetState() {
   if(anchorID != 0) {
      DeleteFiboObjects();
      DeleteLegPoints();
   }
   signalType = STOP_SEARCH;
   currentStatus = WAITING_FOR_COMMAND;
   anchorID = 0;
   anchor.price = 0; mother.price = 0; temporary.price = 0; finalPoint.price = 0;
   anchor.time = 0; mother.time = 0; temporary.time = 0; finalPoint.time = 0;
   anchor.position = 0; mother.position = 0; temporary.position = 0; finalPoint.position = 0;
   isEntryZoneActive = false;
   isInFocusMode = false;
   isAnchorLocked = false;
   finalFiboScenario = "";
   entryZoneActivationTime = 0;
   UpdateStatusPanel();
}

//+------------------------------------------------------------------+
//| ایجاد پنل وضعیت (CreateStatusPanel)                              |
//+------------------------------------------------------------------+

void CHipoFibonacci::CreateStatusPanel() {
   ObjectCreate(0, "HipoFibonacci_Panel_BG", OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, "HipoFibonacci_Panel_BG", OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(0, "HipoFibonacci_Panel_BG", OBJPROP_YDISTANCE, 10);
   ObjectSetInteger(0, "HipoFibonacci_Panel_BG", OBJPROP_XSIZE, 220);
   ObjectSetInteger(0, "HipoFibonacci_Panel_BG", OBJPROP_YSIZE, 100);
   ObjectSetInteger(0, "HipoFibonacci_Panel_BG", OBJPROP_BGCOLOR, clrBlack);
   ObjectSetInteger(0, "HipoFibonacci_Panel_BG", OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, "HipoFibonacci_Panel_BG", OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, "HipoFibonacci_Panel_BG", OBJPROP_CORNER, CORNER_LEFT_UPPER);

   ObjectCreate(0, "HipoFibonacci_Panel_Title", OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, "HipoFibonacci_Panel_Title", OBJPROP_XDISTANCE, 15);
   ObjectSetInteger(0, "HipoFibonacci_Panel_Title", OBJPROP_YDISTANCE, 15);
   ObjectSetInteger(0, "HipoFibonacci_Panel_Title", OBJPROP_ZORDER, 1);
   ObjectSetInteger(0, "HipoFibonacci_Panel_Title", OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, "HipoFibonacci_Panel_Title", OBJPROP_FONTSIZE, 12);
   ObjectSetString(0, "HipoFibonacci_Panel_Title", OBJPROP_FONT, "Arial Bold");
   ObjectSetInteger(0, "HipoFibonacci_Panel_Title", OBJPROP_COLOR, clrGold);
   ObjectSetString(0, "HipoFibonacci_Panel_Title", OBJPROP_TEXT, "وضعیت فیبوناچی");

   ObjectCreate(0, "HipoFibonacci_Panel_Separator", OBJ_HLINE, 0, 0, 0);
   ObjectSetInteger(0, "HipoFibonacci_Panel_Separator", OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(0, "HipoFibonacci_Panel_Separator", OBJPROP_YDISTANCE, 35);
   ObjectSetInteger(0, "HipoFibonacci_Panel_Separator", OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, "HipoFibonacci_Panel_Separator", OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, "HipoFibonacci_Panel_Separator", OBJPROP_WIDTH, 1);

   ObjectCreate(0, "HipoFibonacci_Panel_Status", OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, "HipoFibonacci_Panel_Status", OBJPROP_XDISTANCE, 15);
   ObjectSetInteger(0, "HipoFibonacci_Panel_Status", OBJPROP_YDISTANCE, 50);
   ObjectSetInteger(0, "HipoFibonacci_Panel_Status", OBJPROP_ZORDER, 1);
   ObjectSetInteger(0, "HipoFibonacci_Panel_Status", OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, "HipoFibonacci_Panel_Status", OBJPROP_FONTSIZE, 10);
   ObjectSetString(0, "HipoFibonacci_Panel_Status", OBJPROP_FONT, "Arial Bold");
   ObjectSetInteger(0, "HipoFibonacci_Panel_Status", OBJPROP_COLOR, clrWhite);

   ObjectCreate(0, "HipoFibonacci_Panel_Signal", OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, "HipoFibonacci_Panel_Signal", OBJPROP_XDISTANCE, 15);
   ObjectSetInteger(0, "HipoFibonacci_Panel_Signal", OBJPROP_YDISTANCE, 70);
   ObjectSetInteger(0, "HipoFibonacci_Panel_Signal", OBJPROP_ZORDER, 1);
   ObjectSetInteger(0, "HipoFibonacci_Panel_Signal", OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, "HipoFibonacci_Panel_Signal", OBJPROP_FONTSIZE, 10);
   ObjectSetString(0, "HipoFibonacci_Panel_Signal", OBJPROP_FONT, "Arial Bold");
   ObjectSetInteger(0, "HipoFibonacci_Panel_Signal", OBJPROP_COLOR, clrWhite);

   UpdateStatusPanel();
}

//+------------------------------------------------------------------+
//| به‌روزرسانی پنل وضعیت (UpdateStatusPanel)                        |
//+------------------------------------------------------------------+

void CHipoFibonacci::UpdateStatusPanel() {
   if(!settings.Enable_Status_Panel) return;

   string statusText = "● وضعیت: ";
   switch(currentStatus) {
      case WAITING_FOR_COMMAND: statusText += "منتظر دستور"; break;
      case SEARCHING_FOR_LEG: statusText += "جستجوی لگ حرکتی"; break;
      case SEARCHING_FOR_ANCHOR_DYNAMIC: statusText += "جستجوی لنگرگاه دینامیک"; break;
      case MONITORING_SCENARIO_1_PROGRESS: statusText += "پایش سناریو ۱"; break;
      case SCENARIO_1_AWAITING_BREAKOUT: statusText += "سناریو ۱ - انتظار شکست"; break;
      case SCENARIO_1_CONFIRMED_AWAITING_ENTRY: statusText += "سناریو ۱ - انتظار ورود"; break;
      case SCENARIO_2_ACTIVE_TARGETING_EXTENSION: statusText += "پایش سناریو ۲"; break;
      case SCENARIO_2_CONFIRMED_AWAITING_ENTRY: statusText += "سناریو ۲ - انتظار ورود"; break;
      case ENTRY_ZONE_ACTIVE: statusText += "ناحیه طلایی فعال"; break;
   }
   ObjectSetString(0, "HipoFibonacci_Panel_Status", OBJPROP_TEXT, statusText);
   ObjectSetInteger(0, "HipoFibonacci_Panel_Status", OBJPROP_COLOR, currentStatus == ENTRY_ZONE_ACTIVE ? clrGreen : clrGray);

   string signalText = "● دستور: ";
   color signalColor = clrGray;
   switch(signalType) {
      case SIGNAL_BUY: signalText += "ترند آپ"; signalColor = clrGreen; break;
      case SIGNAL_SELL: signalText += "ترند دان"; signalColor = clrRed; break;
      case STOP_SEARCH: signalText += "توقف"; signalColor = clrGray; break;
   }
   ObjectSetString(0, "HipoFibonacci_Panel_Signal", OBJPROP_TEXT, signalText);
   ObjectSetInteger(0, "HipoFibonacci_Panel_Signal", OBJPROP_COLOR, signalColor);
}
