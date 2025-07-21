/*+------------------------------------------------------------------+
//| HipoTrader.mq5                                                  |
//| Copyright © 2025 HipoAlgorithm                                   |
//| https://hipoalgorithm.com                                        |
//| توضیحات: این اکسپرت با استفاده از اندیکاتور MACD در دو تایم‌فریم، جهت بازار را تشخیص داده و با کتابخانه HipoFibonacci نقاط ورود بهینه را محاسبه می‌کند. مدیریت ریسک و رابط کاربری نیز پیاده‌سازی شده است.
//+------------------------------------------------------------------*/

#property copyright "HipoAlgorithm"
#property link      "https://hipoalgorithm.com"
#property version   "1.0"
#property strict

// شامل کردن کتابخانه‌های مورد نیاز
#include <HipoFibonacci.mqh>
#include <Trade/Trade.mqh>

//+------------------------------------------------------------------+
//| متغیرهای سراسری                                                 |
//| این بخش شامل متغیرهای اصلی اکسپرت است که در کل برنامه استفاده می‌شوند.
//+------------------------------------------------------------------+

CHipoFibonacci HipoFibo;                // نمونه از کلاس کتابخانه HipoFibonacci
CTrade trade;                           // کلاس استاندارد متاتریدر برای مدیریت معاملات
int macd_htf_handle;                    // هندل برای MACD تایم‌فریم بالا
int macd_mtf_handle;                    // هندل برای MACD تایم‌فریم میانی
enum E_Trend { TREND_UP, TREND_DOWN, NEUTRAL }; // انوم برای وضعیت روند
E_Trend currentTrend = NEUTRAL;         // وضعیت فعلی روند
HipoSettings fiboSettings;              // تنظیمات کتابخانه
datetime lastBarTime = 0;               // زمان آخرین کندل برای تشخیص کندل جدید
string lastError = "";                  // ذخیره آخرین خطا برای نمایش

//+------------------------------------------------------------------+
//| پارامترهای ورودی                                                 |
//| این بخش شامل تنظیمات قابل تغییر توسط کاربر است که به صورت گروه‌بندی شده تعریف شده‌اند.
//+------------------------------------------------------------------+

input group "تنظیمات اصلی HipoTrader"
input int MagicNumber = 123456;         // شماره جادویی برای شناسایی معاملات
input double Risk_Percentage_Per_Trade = 1.0; // درصد ریسک در هر معامله (0.1 تا 5.0)
input double Risk_Reward_Ratio = 2.0;   // نسبت ریسک به ریوارد (1.0 تا 5.0)
input double SL_Buffer_Pips = 5.0;      // فاصله اضافی استاپ لاس به پیپ
input int Max_Open_Trades = 1;          // حداکثر تعداد معاملات باز

input group "تنظیمات سیگنال‌دهی MACD HTF (4x)"
input ENUM_TIMEFRAMES HTF_Timeframe = PERIOD_H1; // تایم‌فریم بالا
input int HTF_Fast_EMA = 48;            // دوره EMA سریع (4x)
input int HTF_Slow_EMA = 104;           // دوره EMA کند (4x)
input int HTF_Signal_SMA = 36;          // دوره SMA سیگنال (4x)
input color HTF_MACD_Color = clrBlue;   // رنگ خط MACD HTF
input color HTF_Signal_Color = clrRed;  // رنگ خط سیگنال HTF

input group "تنظیمات سیگنال‌دهی MACD MTF (0.5x)"
input ENUM_TIMEFRAMES MTF_Timeframe = PERIOD_M15; // تایم‌فریم میانی
input int MTF_Fast_EMA = 6;             // دوره EMA سریع (0.5x)
input int MTF_Slow_EMA = 13;            // دوره EMA کند (0.5x)
input int MTF_Signal_SMA = 5;           // دوره SMA سیگنال (0.5x)
input color MTF_MACD_Color = clrGreen;  // رنگ خط MACD MTF
input color MTF_Signal_Color = clrYellow; // رنگ خط سیگنال MTF

input group "تنظیمات نمایش و چارت"
input bool Enable_MACD_Display = true;  // فعال‌سازی نمایش اندیکاتورهای MACD روی چارت
input bool Enable_Confirmation_Filter = false; // فعال‌سازی فیلتر تأیید کندل بعدی

//+------------------------------------------------------------------+
//| تابع راه‌اندازی اولیه (OnInit)                                   |
//| این تابع هنگام شروع اکسپرت اجرا شده و تنظیمات اولیه را اعمال می‌کند.
//+------------------------------------------------------------------+

int OnInit() {
   // غیرفعال کردن خطوط گرید چارت
   ChartSetInteger(ChartID(), CHART_SHOW_GRID, false);
   
   // تنظیم رنگ پس‌زمینه چارت به مشکی
   ChartSetInteger(ChartID(), CHART_COLOR_BACKGROUND, clrBlack);
   
   // تنظیم رنگ کندل‌ها (صعودی سبز، نزولی قرمز)
   ChartSetInteger(ChartID(), CHART_COLOR_CANDLE_BULL, clrGreen);
   ChartSetInteger(ChartID(), CHART_COLOR_CANDLE_BEAR, clrRed);
   ChartSetInteger(ChartID(), CHART_COLOR_CHART_UP, clrGreen);
   ChartSetInteger(ChartID(), CHART_COLOR_CHART_DOWN, clrRed);

   // اعتبارسنجی ورودی‌ها
   if(Risk_Percentage_Per_Trade <= 0 || Risk_Percentage_Per_Trade > 5.0) {
      lastError = "درصد ریسک نامعتبر است (باید بین 0.1 و 5.0 باشد)";
      return INIT_PARAMETERS_INCORRECT;
   }
   if(Risk_Reward_Ratio <= 0 || Risk_Reward_Ratio > 5.0) {
      lastError = "نسبت ریسک به ریوارد نامعتبر است (باید بین 1.0 و 5.0 باشد)";
      return INIT_PARAMETERS_INCORRECT;
   }
   if(SL_Buffer_Pips < 0) {
      lastError = "فاصله استاپ لاس نمی‌تواند منفی باشد";
      return INIT_PARAMETERS_INCORRECT;
   }
   if(HTF_Fast_EMA <= 0 || HTF_Slow_EMA <= 0 || HTF_Signal_SMA <= 0 ||
      MTF_Fast_EMA <= 0 || MTF_Slow_EMA <= 0 || MTF_Signal_SMA <= 0) {
      lastError = "تنظیمات MACD نمی‌تواند صفر یا منفی باشد";
      return INIT_PARAMETERS_INCORRECT;
   }

   // تنظیم اولیه کتابخانه HipoFibonacci
   fiboSettings.CalculationTimeframe = PERIOD_CURRENT; // قابل تغییر توسط کاربر در کتابخانه
   fiboSettings.Enable_Drawing = true;
   fiboSettings.Enable_Logging = true;
   fiboSettings.Enable_Status_Panel = true;
   fiboSettings.MaxCandles = 500;
   fiboSettings.MarginPips = 1.0;
   HipoFibo.Init(fiboSettings);

   // ایجاد هندل‌های MACD
   macd_htf_handle = iMACD(_Symbol, HTF_Timeframe, HTF_Fast_EMA, HTF_Slow_EMA, HTF_Signal_SMA, PRICE_CLOSE);
   macd_mtf_handle = iMACD(_Symbol, MTF_Timeframe, MTF_Fast_EMA, MTF_Slow_EMA, MTF_Signal_SMA, PRICE_CLOSE);
   if(macd_htf_handle == INVALID_HANDLE || macd_mtf_handle == INVALID_HANDLE) {
      lastError = "خطا در ایجاد هندل‌های MACD";
      return INIT_FAILED;
   }

   // ایجاد اندیکاتورهای نمایشی اگر فعال باشند
   if(Enable_MACD_Display) {
      CreateMACDDisplay(HTF_Timeframe, HTF_MACD_Color, HTF_Signal_Color, 0);
      CreateMACDDisplay(MTF_Timeframe, MTF_MACD_Color, MTF_Signal_Color, 1);
   }

   // تنظیم اولیه رابط کاربری
   CreateTraderPanel();
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| تابع آزادسازی منابع (OnDeinit)                                   |
//| این تابع هنگام بسته شدن اکسپرت اجرا شده و منابع را آزاد می‌کند.
//+------------------------------------------------------------------+

void OnDeinit(const int reason) {
   IndicatorRelease(macd_htf_handle);
   IndicatorRelease(macd_mtf_handle);
   ObjectDelete(0, "HipoTrader_Panel");
   if(Enable_MACD_Display) {
      ObjectDelete(0, "HTF_MACD");
      ObjectDelete(0, "MTF_MACD");
   }
}

//+------------------------------------------------------------------+
//| تابع پردازش تیک (OnTick)                                         |
//| این تابع در هر تیک بازار اجرا شده و عملیات سریع را مدیریت می‌کند.
//+------------------------------------------------------------------+

void OnTick() {
   // بررسی تعداد معاملات باز
   if(CountOpenTrades() >= Max_Open_Trades) return;

   // بررسی وضعیت ناحیه طلایی
   if(HipoFibo.IsEntryZoneActive()) return; // منتظر کندل جدید برای پردازش ورود

   // به‌روزرسانی رابط کاربری
   UpdateTraderPanel();

   // مدیریت معاملات در صورت نیاز
   if(PositionsTotal() > 0) return; // اگر معامله‌ای باز است، فقط مدیریت کن
   ExecuteTradeIfReady();
}

//+------------------------------------------------------------------+
//| تابع تشخیص کندل جدید (OnNewBar)                                  |
//| این تابع بررسی می‌کند که آیا کندل جدیدی بسته شده است یا خیر.
//+------------------------------------------------------------------+

bool OnNewBar() {
   datetime currentTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   if(currentTime != lastBarTime) {
      lastBarTime = currentTime;
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| تابع پردازش اصلی (CoreProcessing)                                |
//| این تابع منطق اصلی تحلیل و ارسال دستور به کتابخانه را اجرا می‌کند.
//+------------------------------------------------------------------+

void CoreProcessing() {
   // دریافت داده‌های MACD
   double htf_main[], htf_signal[], mtf_main[], mtf_signal[];
   if(CopyBuffer(macd_htf_handle, 0, 1, 2, htf_main) < 2 || CopyBuffer(macd_htf_handle, 1, 1, 2, htf_signal) < 2 ||
      CopyBuffer(macd_mtf_handle, 0, 1, 2, mtf_main) < 2 || CopyBuffer(macd_mtf_handle, 1, 1, 2, mtf_signal) < 2) {
      lastError = "خطا در کپی داده‌های MACD";
      return;
   }

   // تحلیل سیگنال‌ها
   bool htf_buy_permission = (htf_main[1] > htf_signal[1]);
   bool htf_sell_permission = (htf_signal[1] > htf_main[1]);
   bool mtf_buy_trigger = (mtf_main[1] < 0);
   bool mtf_sell_trigger = (mtf_main[1] > 0);

   // تعیین روند جدید
   E_Trend newTrend = NEUTRAL;
   if(htf_buy_permission && mtf_buy_trigger && !Enable_Confirmation_Filter) newTrend = TREND_UP;
   else if(htf_sell_permission && mtf_sell_trigger && !Enable_Confirmation_Filter) newTrend = TREND_DOWN;
   else if(Enable_Confirmation_Filter) {
      if(OnNewBar() && htf_buy_permission && mtf_buy_trigger) newTrend = TREND_UP;
      else if(OnNewBar() && htf_sell_permission && mtf_sell_trigger) newTrend = TREND_DOWN;
   }

   // ارسال دستور به کتابخانه در صورت تغییر روند
   if(newTrend != currentTrend) {
      currentTrend = newTrend;
      E_SignalType signal = STOP_SEARCH;
      if(newTrend == TREND_UP) signal = SIGNAL_BUY;
      else if(newTrend == TREND_DOWN) signal = SIGNAL_SELL;
      HipoFibo.ReceiveCommand(signal, PERIOD_CURRENT);
      if(signal == STOP_SEARCH) HipoFibo.ReceiveCommand(STOP_SEARCH, PERIOD_CURRENT); // پاک‌سازی داخلی
   }

   // پردازش کندل جدید
   if(OnNewBar()) {
      MqlRates rates[];
      ArraySetAsSeries(rates, true);
      if(CopyRates(_Symbol, PERIOD_CURRENT, 0, 2, rates) < 2) {
         lastError = "خطا در کپی داده‌های قیمت";
         return;
      }
      datetime times[2];
      double opens[2], highs[2], lows[2], closes[2];
      ArrayCopy(times, rates.Time);
      ArrayCopy(opens, rates.Open);
      ArrayCopy(highs, rates.High);
      ArrayCopy(lows, rates.Low);
      ArrayCopy(closes, rates.Close);
      HipoFibo.OnNewCandle(2, times, opens, highs, lows, closes);
   }
}

//+------------------------------------------------------------------+
//| تابع اجرای معامله (ExecuteTrade)                                 |
//| این تابع زمانی فراخوانی می‌شود که ناحیه طلایی فعال باشد.
//+------------------------------------------------------------------+

void ExecuteTrade() {
   if(CountOpenTradesInZone() > 0) return; // جلوگیری از ورود چندگانه در یک ناحیه

   double sl_price = 0;
   if(!HipoFibo.GetFiboLevelPrice(FIBO_MOTHER, 0, sl_price)) {
      lastError = "قیمت استاپ لاس نامعتبر است";
      return;
   }

   double entry_price = SymbolInfoDouble(_Symbol, SYMBOL_ASK); // برای خرید
   if(currentTrend == TREND_DOWN) entry_price = SymbolInfoDouble(_Symbol, SYMBOL_BID); // برای فروش
   double spread = SymbolInfoDouble(_Symbol, SYMBOL_SPREAD) * _Point;
   double final_sl_price = (currentTrend == TREND_UP) ? sl_price - SL_Buffer_Pips * _Point - spread : sl_price + SL_Buffer_Pips * _Point + spread;
   double sl_distance = MathAbs(entry_price - final_sl_price) / _Point;
   double tick_value = 0;
   SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE, tick_value);
   double volume = (AccountBalance() * Risk_Percentage_Per_Trade / 100) / (sl_distance * tick_value);
   volume = NormalizeDouble(volume, 2);

   double tp_distance = sl_distance * Risk_Reward_Ratio;
   double take_profit = (currentTrend == TREND_UP) ? entry_price + tp_distance * _Point + spread : entry_price - tp_distance * _Point - spread;

   // ارسال معامله با پذیرش لغزش
   if(currentTrend == TREND_UP) {
      if(!trade.Buy(volume, _Symbol, entry_price, final_sl_price, take_profit, "Buy Order", MagicNumber, 3)) {
         lastError = "خطا در ارسال سفارش خرید: " + IntegerToString(GetLastError());
      }
   } else if(currentTrend == TREND_DOWN) {
      if(!trade.Sell(volume, _Symbol, entry_price, final_sl_price, take_profit, "Sell Order", MagicNumber, 3)) {
         lastError = "خطا در ارسال سفارش فروش: " + IntegerToString(GetLastError());
      }
   }

   if(trade.ResultRetcode() == TRADE_RETCODE_DONE) {
      HipoFibo.ReceiveCommand(STOP_SEARCH, PERIOD_CURRENT);
      Print("معامله با موفقیت اجرا شد - حجم: ", volume, "، SL: ", final_sl_price, "، TP: ", take_profit);
   }
}

//+------------------------------------------------------------------+
//| تابع اجرای معامله در صورت آمادگی (ExecuteTradeIfReady)           |
//| این تابع بررسی می‌کند که آیا شرایط ورود به معامله فراهم است یا خیر.
//+------------------------------------------------------------------+

void ExecuteTradeIfReady() {
   if(HipoFibo.IsEntryZoneActive()) ExecuteTrade();
}

//+------------------------------------------------------------------+
//| تابع شمارش معاملات باز (CountOpenTrades)                         |
//| این تابع تعداد معاملات باز با MagicNumber مشخص را محاسبه می‌کند.
//+------------------------------------------------------------------+

int CountOpenTrades() {
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == MagicNumber) {
         count++;
      }
   }
   return count;
}

//+------------------------------------------------------------------+
//| تابع شمارش معاملات در ناحیه طلایی (CountOpenTradesInZone)       |
//| این تابع تعداد معاملات باز در ناحیه طلایی فعلی را بررسی می‌کند.
//+------------------------------------------------------------------+

int CountOpenTradesInZone() {
   if(!HipoFibo.IsEntryZoneActive()) return 0;
   datetime zoneTime = HipoFibo.GetEntryZoneActivationTime();
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == MagicNumber &&
         PositionGetInteger(POSITION_TIME) >= zoneTime) {
         count++;
      }
   }
   return count;
}

//+------------------------------------------------------------------+
//| تابع ایجاد اندیکاتور نمایشی (CreateMACDDisplay)                  |
//| این تابع اندیکاتور MACD را برای نمایش روی چارت ایجاد می‌کند.
//+------------------------------------------------------------------+

void CreateMACDDisplay(ENUM_TIMEFRAMES timeframe, color macdColor, color signalColor, int subwindow) {
   string name = (subwindow == 0) ? "HTF_MACD" : "MTF_MACD";
   int handle = iMACD(_Symbol, timeframe, HTF_Fast_EMA, HTF_Slow_EMA, HTF_Signal_SMA, PRICE_CLOSE);
   if(handle != INVALID_HANDLE) {
      IndicatorSetInteger(INDICATOR_DIGITS, 5);
      IndicatorSetString(INDICATOR_SHORTNAME, name);
      if(subwindow > 0) ChartIndicatorAdd(ChartID(), subwindow, handle);
      IndicatorRelease(handle);
   }
}

//+------------------------------------------------------------------+
//| تابع ایجاد پنل رابط کاربری (CreateTraderPanel)                   |
//| این تابع پنل وضعیت اکسپرت را روی چارت ایجاد می‌کند.
//+------------------------------------------------------------------+

void CreateTraderPanel() {
   ObjectCreate(0, "HipoTrader_Panel", OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, "HipoTrader_Panel", OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(0, "HipoTrader_Panel", OBJPROP_YDISTANCE, 70); // زیر پنل HipoFibonacci
   ObjectSetInteger(0, "HipoTrader_Panel", OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, "HipoTrader_Panel", OBJPROP_FONTSIZE, 10);
   ObjectSetString(0, "HipoTrader_Panel", OBJPROP_FONT, "Arial");
   UpdateTraderPanel();
}

//+------------------------------------------------------------------+
//| تابع به‌روزرسانی پنل رابط کاربری (UpdateTraderPanel)            |
//| این تابع اطلاعات پنل را به‌روز می‌کند.
//+------------------------------------------------------------------+

void UpdateTraderPanel() {
   string statusText = "HipoTrader Panel\n";
   color htfColor = (currentTrend == TREND_UP) ? clrGreen : (currentTrend == TREND_DOWN) ? clrRed : clrGray;
   statusText += "HTF Signal (H1): " + CharToString(110) + " [رنگ: " + GetColorName(htfColor) + "]\n";
   color mtfColor = (currentTrend == TREND_UP && HipoFibo.GetCurrentStatus() == ENTRY_ZONE_ACTIVE) ? clrGreen : 
                    (currentTrend == TREND_DOWN && HipoFibo.GetCurrentStatus() == ENTRY_ZONE_ACTIVE) ? clrRed : clrGray;
   statusText += "MTF Signal (M15): " + CharToString(110) + " [رنگ: " + GetColorName(mtfColor) + "]\n";
   string fiboStatus = EnumToString(HipoFibo.GetCurrentStatus());
   statusText += "HipoFibo Status: " + fiboStatus + "\n";
   string overallStatus = (HipoFibo.IsEntryZoneActive()) ? "در انتظار ورود..." : 
                         (PositionsTotal() > 0) ? "معامله باز..." : "جستجوی سیگنال...";
   statusText += "وضعیت کلی: " + overallStatus;

   ObjectSetString(0, "HipoTrader_Panel", OBJPROP_TEXT, statusText);
   ObjectSetInteger(0, "HipoTrader_Panel", OBJPROP_COLOR, clrWhite);
}

//+------------------------------------------------------------------+
//| تابع تبدیل رنگ به نام (GetColorName)                             |
//| این تابع رنگ را به نام متنی تبدیل می‌کند.
//+------------------------------------------------------------------+

string GetColorName(color clr) {
   if(clr == clrGreen) return "سبز";
   if(clr == clrRed) return "قرمز";
   return "خاکستری";
}
