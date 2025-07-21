//+------------------------------------------------------------------+
//| HipoTrader.mq5                                                  |
//| Copyright © 2025 HipoAlgorithm                                   |
//| https://hipoalgorithm.com                                        |
//| نسخه: 3.0                                                        |
//| توضیحات: اکسپرت معاملاتی با منطق چند تایم‌فریمی، مبتنی بر MACD و کتابخانه HipoFibonacci نسخه 3.0. |
//| هماهنگی: این کد با نسخه 3.0 کتابخانه HipoFibonacci.mqh طراحی شده است. |
//+------------------------------------------------------------------+

#property copyright "HipoAlgorithm"
#property link      "https://hipoalgorithm.com"
#property version   "3.0"
#property strict

// شامل کردن کتابخانه‌های مورد نیاز
#include <HipoFibonacci.mqh>
#include <Trade/Trade.mqh>

//+------------------------------------------------------------------+
//| متغیرهای سراسری                                                 |
//+------------------------------------------------------------------+

CHipoFibonacci HipoFibo;                // نمونه از کلاس CHipoFibonacci
CTrade trade;                           // کلاس مدیریت معاملات
int macd_htf_handle;                    // هندل MACD تایم‌فریم بالا
int macd_mtf_handle;                    // هندل MACD تایم‌فریم میانی
enum E_Trend { TREND_UP, TREND_DOWN, NEUTRAL }; // تعریف انوم برای روند
E_Trend currentTrend = NEUTRAL;         // وضعیت فعلی روند
bool isCommandSent = false;             // قفل برای ارسال دستور
HipoSettings fiboSettings;              // تنظیمات کتابخانه
datetime lastCalculationBarTime = 0;    // زمان آخرین کندل محاسباتی
string lastError = "";                  // ذخیره آخرین خطا
datetime lastErrorTime = 0;             // زمان ثبت آخرین خطا

//+------------------------------------------------------------------+
//| پارامترهای ورودی                                                 |
//+------------------------------------------------------------------+

input group "تنظیمات اصلی HipoTrader"
input int MagicNumber = 123456;         // شماره جادویی برای شناسایی معاملات
input double Risk_Percentage_Per_Trade = 1.0; // درصد ریسک در هر معامله (0.1 تا 5.0)
input double Risk_Reward_Ratio = 2.0;   // نسبت ریسک به ریوارد (1.0 تا 5.0)
input double SL_Buffer_Pips = 5.0;      // فاصله اضافی استاپ لاس به پیپ
input int Max_Open_Trades = 1;          // حداکثر تعداد معاملات باز

input group "تنظیمات سیگنال‌دهی MACD HTF (4x)"
input ENUM_TIMEFRAMES HTF_Timeframe = PERIOD_H1; // تایم‌فریم بالا برای تحلیل روند
input int HTF_Fast_EMA = 48;            // دوره EMA سریع
input int HTF_Slow_EMA = 104;           // دوره EMA کند
input int HTF_Signal_SMA = 36;          // دوره SMA سیگنال
input color HTF_MACD_Color = clrBlue;   // رنگ خط MACD برای HTF
input color HTF_Signal_Color = clrRed;  // رنگ خط سیگنال برای HTF

input group "تنظیمات سیگنال‌دهی MACD MTF (0.5x)"
input ENUM_TIMEFRAMES MTF_Timeframe = PERIOD_M15; // تایم‌فریم میانی برای ماشه
input int MTF_Fast_EMA = 6;             // دوره EMA سریع
input int MTF_Slow_EMA = 13;            // دوره EMA کند
input int MTF_Signal_SMA = 5;           // دوره SMA سیگنال
input color MTF_MACD_Color = clrGreen;  // رنگ خط MACD برای MTF
input color MTF_Signal_Color = clrYellow; // رنگ خط سیگنال برای MTF

input group "تنظیمات نمایش و چارت"
input bool Enable_MACD_Display = true;  // فعال‌سازی نمایش اندیکاتورهای MACD
input bool Enable_Confirmation_Filter = false; // فعال‌سازی فیلتر تأیید کندل بعدی

input group "تنظیمات کتابخانه HipoFibonacci"
input ENUM_TIMEFRAMES HipoFibo_CalculationTimeframe = PERIOD_M5; // تایم‌فریم محاسباتی
input int HipoFibo_SearchWindow = 200;  // بازه جستجو برای فراکتال
input int HipoFibo_Fractal_Lookback = 10; // تعداد کندل‌های فراکتال
input double HipoFibo_Min_Leg_Size_Pips = 15.0; // حداقل اندازه لگ به پیپ
input double HipoFibo_EntryZone_LowerLevel = 50.0; // سطح پایین ناحیه ورود
input double HipoFibo_EntryZone_UpperLevel = 68.0; // سطح بالا ناحیه ورود
input color HipoFibo_MotherFibo_Color = clrGray; // رنگ فیبوناچی مادر
input color HipoFibo_IntermediateFibo_Color = clrLemonChiffon; // رنگ فیبوناچی میانی
input color HipoFibo_BuyEntryFibo_Color = clrLightGreen; // رنگ ناحیه ورود خرید
input color HipoFibo_SellEntryFibo_Color = clrRed; // رنگ ناحیه ورود فروش

//+------------------------------------------------------------------+
//| تابع راه‌اندازی اولیه (OnInit)                                   |
//+------------------------------------------------------------------+

int OnInit() {
   if(!ChartSetInteger(ChartID(), CHART_SHOW_GRID, false)) {
      lastError = "خطا در غیرفعال کردن گرید چارت";
      lastErrorTime = TimeCurrent();
      return INIT_FAILED;
   }

   if(!ChartSetInteger(ChartID(), CHART_COLOR_BACKGROUND, clrBlack) ||
      !ChartSetInteger(ChartID(), CHART_COLOR_CANDLE_BULL, clrGreen) ||
      !ChartSetInteger(ChartID(), CHART_COLOR_CANDLE_BEAR, clrRed) ||
      !ChartSetInteger(ChartID(), CHART_COLOR_CHART_UP, clrGreen) ||
      !ChartSetInteger(ChartID(), CHART_COLOR_CHART_DOWN, clrRed)) {
      lastError = "خطا در تنظیم رنگ‌های چارت";
      lastErrorTime = TimeCurrent();
      return INIT_FAILED;
   }

   if(Risk_Percentage_Per_Trade <= 0.0 || Risk_Percentage_Per_Trade > 5.0) {
      lastError = "درصد ریسک نامعتبر است (باید بین 0.1 و 5.0 باشد)";
      lastErrorTime = TimeCurrent();
      return INIT_PARAMETERS_INCORRECT;
   }
   if(Risk_Reward_Ratio <= 0.0 || Risk_Reward_Ratio > 5.0) {
      lastError = "نسبت ریسک به ریوارد نامعتبر است (باید بین 1.0 و 5.0 باشد)";
      lastErrorTime = TimeCurrent();
      return INIT_PARAMETERS_INCORRECT;
   }
   if(SL_Buffer_Pips < 0.0) {
      lastError = "فاصله استاپ لاس نمی‌تواند منفی باشد";
      lastErrorTime = TimeCurrent();
      return INIT_PARAMETERS_INCORRECT;
   }
   if(HipoFibo_SearchWindow <= 0) {
      lastError = "تنظیمات SearchWindow نمی‌تواند صفر یا منفی باشد";
      lastErrorTime = TimeCurrent();
      return INIT_PARAMETERS_INCORRECT;
   }
   if(HipoFibo_Fractal_Lookback <= 0) {
      lastError = "تنظیمات Fractal_Lookback نمی‌تواند صفر یا منفی باشد";
      lastErrorTime = TimeCurrent();
      return INIT_PARAMETERS_INCORRECT;
   }
   if(HipoFibo_EntryZone_LowerLevel >= HipoFibo_EntryZone_UpperLevel) {
      lastError = "سطح پایین ناحیه ورود باید کمتر از سطح بالا باشد";
      lastErrorTime = TimeCurrent();
      return INIT_PARAMETERS_INCORRECT;
   }
   if(HipoFibo_Min_Leg_Size_Pips < 0.0) {
      lastError = "حداقل اندازه لگ نمی‌تواند منفی باشد";
      lastErrorTime = TimeCurrent();
      return INIT_PARAMETERS_INCORRECT;
   }

   fiboSettings.CalculationTimeframe = HipoFibo_CalculationTimeframe;
   fiboSettings.Enable_Drawing = true;
   fiboSettings.Enable_Logging = true;
   fiboSettings.Enable_Status_Panel = true;
   fiboSettings.MaxCandles = 500;
   fiboSettings.MarginPips = 1.0;
   fiboSettings.SearchWindow = HipoFibo_SearchWindow;
   fiboSettings.Fractal_Lookback = HipoFibo_Fractal_Lookback;
   fiboSettings.Min_Leg_Size_Pips = HipoFibo_Min_Leg_Size_Pips;
   fiboSettings.EntryZone_LowerLevel = HipoFibo_EntryZone_LowerLevel;
   fiboSettings.EntryZone_UpperLevel = HipoFibo_EntryZone_UpperLevel;
   fiboSettings.MotherFibo_Color = HipoFibo_MotherFibo_Color;
   fiboSettings.IntermediateFibo_Color = HipoFibo_IntermediateFibo_Color;
   fiboSettings.BuyEntryFibo_Color = HipoFibo_BuyEntryFibo_Color;
   fiboSettings.SellEntryFibo_Color = HipoFibo_SellEntryFibo_Color;
   HipoFibo.Init(fiboSettings);

   macd_htf_handle = iMACD(_Symbol, HTF_Timeframe, HTF_Fast_EMA, HTF_Slow_EMA, HTF_Signal_SMA, PRICE_CLOSE);
   macd_mtf_handle = iMACD(_Symbol, MTF_Timeframe, MTF_Fast_EMA, MTF_Slow_EMA, MTF_Signal_SMA, PRICE_CLOSE);
   if(macd_htf_handle == INVALID_HANDLE || macd_mtf_handle == INVALID_HANDLE) {
      lastError = "خطا در ایجاد هندل‌های MACD";
      lastErrorTime = TimeCurrent();
      return INIT_FAILED;
   }

   if(Enable_MACD_Display) {
      CreateMACDDisplay(HTF_Timeframe, HTF_MACD_Color, HTF_Signal_Color, 0);
      CreateMACDDisplay(MTF_Timeframe, MTF_MACD_Color, MTF_Signal_Color, 1);
   }

   CreateTraderPanel();
   EventSetTimer(1);
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| تابع آزادسازی منابع (OnDeinit)                                   |
//+------------------------------------------------------------------+

void OnDeinit(const int reason) {
   if(macd_htf_handle != INVALID_HANDLE) IndicatorRelease(macd_htf_handle);
   if(macd_mtf_handle != INVALID_HANDLE) IndicatorRelease(macd_mtf_handle);
   ObjectDelete(0, "HipoTrader_Panel_BG");
   ObjectDelete(0, "HipoTrader_Panel_Trend");
   ObjectDelete(0, "HipoTrader_Panel_HTF");
   ObjectDelete(0, "HipoTrader_Panel_MTF");
   ObjectDelete(0, "HipoTrader_Panel_Fibo");
   ObjectDelete(0, "HipoTrader_Panel_Status");
   if(Enable_MACD_Display) {
      ObjectDelete(0, "HTF_MACD");
      ObjectDelete(0, "MTF_MACD");
   }
   EventKillTimer();
}

//+------------------------------------------------------------------+
//| تابع پردازش تیک (OnTick)                                         |
//+------------------------------------------------------------------+

void OnTick() {
   // خالی برای عملکرد بهینه
}

//+------------------------------------------------------------------+
//| تابع پردازش زمان‌بندی (OnTimer)                                  |
//+------------------------------------------------------------------+

void OnTimer() {
   if(TimeCurrent() - lastErrorTime > 10 && lastError != "") {
      lastError = "";
      lastErrorTime = 0;
   }

   if(isCommandSent && HipoFibo.GetCurrentStatus() == SEARCHING_FOR_LEG) {
      isCommandSent = false;
      Print("کتابخانه ساختار قبلی را تمام کرده. اکسپرت آماده ارسال دستور جدید است.");
   }

   if(IsNewCalculationBar()) {
      CoreProcessing();
      int bars_to_copy = fiboSettings.SearchWindow + 2 * fiboSettings.Fractal_Lookback + 5;
      MqlRates rates[];
      ArraySetAsSeries(rates, true);
      if(CopyRates(_Symbol, fiboSettings.CalculationTimeframe, 0, bars_to_copy, rates) >= bars_to_copy) {
         HipoFibo.OnNewCandle(rates);
      } else {
         lastError = "تعداد کندل‌های کافی در تاریخچه برای تحلیل وجود ندارد.";
         lastErrorTime = TimeCurrent();
         Print(lastError);
      }
   }

   UpdateTraderPanel();
   ExecuteTradeIfReady();
}

//+------------------------------------------------------------------+
//| تابع تشخیص کندل جدید (IsNewCalculationBar)                       |
//+------------------------------------------------------------------+

bool IsNewCalculationBar() {
   datetime currentTime = iTime(_Symbol, fiboSettings.CalculationTimeframe, 0);
   if(currentTime != lastCalculationBarTime) {
      lastCalculationBarTime = currentTime;
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| تابع پردازش اصلی (CoreProcessing)                               |
//+------------------------------------------------------------------+

void CoreProcessing() {
   double htf_main[2], htf_signal[2], mtf_main[2];
   if(CopyBuffer(macd_htf_handle, 0, 0, 2, htf_main) < 2 || 
      CopyBuffer(macd_htf_handle, 1, 0, 2, htf_signal) < 2 ||
      CopyBuffer(macd_mtf_handle, 0, 0, 2, mtf_main) < 2) {
      lastError = "خطا در کپی داده‌های MACD";
      lastErrorTime = TimeCurrent();
      return;
   }

   bool htf_buy_permission = (htf_main[1] > htf_signal[1]);
   bool htf_sell_permission = (htf_main[1] < htf_signal[1]);
   bool mtf_buy_trigger = (mtf_main[1] < 0);
   bool mtf_sell_trigger = (mtf_main[1] > 0);

   if(!isCommandSent) {
      if(Enable_Confirmation_Filter) {
         bool htf_buy_prev = (htf_main[0] > htf_signal[0]);
         bool htf_sell_prev = (htf_main[0] < htf_signal[0]);
         bool mtf_buy_prev = (mtf_main[0] < 0);
         bool mtf_sell_prev = (mtf_main[0] > 0);
         if(htf_buy_permission && mtf_buy_trigger && htf_buy_prev && mtf_buy_prev) {
            currentTrend = TREND_UP;
            HipoFibo.ReceiveCommand(SIGNAL_BUY, fiboSettings.CalculationTimeframe);
            isCommandSent = true;
            Print("سیگنال خرید جدید با تأیید کندل دریافت شد.");
         }
         else if(htf_sell_permission && mtf_sell_trigger && htf_sell_prev && mtf_sell_prev) {
            currentTrend = TREND_DOWN;
            HipoFibo.ReceiveCommand(SIGNAL_SELL, fiboSettings.CalculationTimeframe);
            isCommandSent = true;
            Print("سیگنال فروش جدید با تأیید کندل دریافت شد.");
         }
      } else {
         if(htf_buy_permission && mtf_buy_trigger) {
            currentTrend = TREND_UP;
            HipoFibo.ReceiveCommand(SIGNAL_BUY, fiboSettings.CalculationTimeframe);
            isCommandSent = true;
            Print("سیگنال خرید جدید دریافت شد.");
         }
         else if(htf_sell_permission && mtf_sell_trigger) {
            currentTrend = TREND_DOWN;
            HipoFibo.ReceiveCommand(SIGNAL_SELL, fiboSettings.CalculationTimeframe);
            isCommandSent = true;
            Print("سیگنال فروش جدید دریافت شد.");
         }
      }
   } else {
      if(currentTrend == TREND_UP && !htf_buy_permission) {
         Print("روند HTF برای خرید از بین رفت. ارسال دستور توقف.");
         HipoFibo.ReceiveCommand(STOP_SEARCH, fiboSettings.CalculationTimeframe);
         isCommandSent = false;
         currentTrend = NEUTRAL;
      }
      else if(currentTrend == TREND_DOWN && !htf_sell_permission) {
         Print("روند HTF برای فروش از بین رفت. ارسال دستور توقف.");
         HipoFibo.ReceiveCommand(STOP_SEARCH, fiboSettings.CalculationTimeframe);
         isCommandSent = false;
         currentTrend = NEUTRAL;
      }
   }
}

//+------------------------------------------------------------------+
//| تابع اجرای معامله (ExecuteTrade)                                 |
//+------------------------------------------------------------------+

void ExecuteTrade() {
   if(CountOpenTradesInZone() > 0) return;

   double sl_price = HipoFibo.GetFiboLevelPrice(FIBO_MOTHER, 0.0);
   if(sl_price == 0.0) {
      lastError = "خطا در دریافت قیمت استاپ لاس از کتابخانه";
      lastErrorTime = TimeCurrent();
      return;
   }

   double entry_price = 0.0;
   if(currentTrend == TREND_UP) {
      entry_price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry_price == 0.0) {
         lastError = "خطا در دریافت قیمت ASK";
         lastErrorTime = TimeCurrent();
         return;
      }
   } else if(currentTrend == TREND_DOWN) {
      entry_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry_price == 0.0) {
         lastError = "خطا در دریافت قیمت BID";
         lastErrorTime = TimeCurrent();
         return;
      }
   }

   long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   double spread = spread_points * _Point;

   double final_sl_price = (currentTrend == TREND_UP) ? sl_price - SL_Buffer_Pips * _Point - spread : sl_price + SL_Buffer_Pips * _Point + spread;
   double sl_distance = MathAbs(entry_price - final_sl_price) / _Point;

   double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   if(tick_value == 0.0) {
      lastError = "خطا در دریافت ارزش تیک";
      lastErrorTime = TimeCurrent();
      return;
   }
   double volume = (AccountInfoDouble(ACCOUNT_BALANCE) * Risk_Percentage_Per_Trade / 100.0) / (sl_distance * tick_value);
   volume = NormalizeDouble(volume, 2);

   double tp_distance = sl_distance * Risk_Reward_Ratio;
   double take_profit = (currentTrend == TREND_UP) ? entry_price + tp_distance * _Point + spread : entry_price - tp_distance * _Point - spread;

   if(currentTrend == TREND_UP) {
      if(!trade.Buy(volume, _Symbol, entry_price, final_sl_price, take_profit, "Buy Order - HipoTrader")) {
         lastError = "خطا در ارسال سفارش خرید: " + IntegerToString(GetLastError());
         lastErrorTime = TimeCurrent();
      }
   } else if(currentTrend == TREND_DOWN) {
      if(!trade.Sell(volume, _Symbol, entry_price, final_sl_price, take_profit, "Sell Order - HipoTrader")) {
         lastError = "خطا در ارسال سفارش فروش: " + IntegerToString(GetLastError());
         lastErrorTime = TimeCurrent();
      }
   }

   HipoFibo.ReceiveCommand(STOP_SEARCH, fiboSettings.CalculationTimeframe);
   isCommandSent = false;

   if(trade.ResultRetcode() == TRADE_RETCODE_DONE) {
      Print("معامله با موفقیت اجرا شد - حجم: ", volume, ", SL: ", final_sl_price, ", TP: ", take_profit);
      HipoFibo.OnTradePerformed();
   } else {
      Print("تلاش برای ورود به معامله انجام شد اما با خطا مواجه شد: ", lastError);
   }
}

//+------------------------------------------------------------------+
//| تابع اجرای معامله در صورت آمادگی (ExecuteTradeIfReady)           |
//+------------------------------------------------------------------+

void ExecuteTradeIfReady() {
   if(HipoFibo.IsEntryZoneActive()) ExecuteTrade();
}

//+------------------------------------------------------------------+
//| تابع شمارش معاملات باز (CountOpenTrades)                         |
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
//+------------------------------------------------------------------+

void CreateMACDDisplay(ENUM_TIMEFRAMES timeframe, color macdColor, color signalColor, int subwindow) {
   string name = (subwindow == 0) ? "HTF_MACD" : "MTF_MACD";
   int handle = iMACD(_Symbol, timeframe, HTF_Fast_EMA, HTF_Slow_EMA, HTF_Signal_SMA, PRICE_CLOSE);
   if(handle != INVALID_HANDLE) {
      IndicatorSetInteger(INDICATOR_DIGITS, 5);
      IndicatorSetString(INDICATOR_SHORTNAME, name);
      if(subwindow > 0) ChartIndicatorAdd(ChartID(), subwindow, handle);
   }
}

//+------------------------------------------------------------------+
//| تابع ایجاد پنل رابط کاربری (CreateTraderPanel)                   |
//+------------------------------------------------------------------+

void CreateTraderPanel() {
   ObjectCreate(0, "HipoTrader_Panel_BG", OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, "HipoTrader_Panel_BG", OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(0, "HipoTrader_Panel_BG", OBJPROP_YDISTANCE, 100);
   ObjectSetInteger(0, "HipoTrader_Panel_BG", OBJPROP_XSIZE, 220);
   ObjectSetInteger(0, "HipoTrader_Panel_BG", OBJPROP_YSIZE, 140);
   ObjectSetInteger(0, "HipoTrader_Panel_BG", OBJPROP_BGCOLOR, clrBlack);
   ObjectSetInteger(0, "HipoTrader_Panel_BG", OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, "HipoTrader_Panel_BG", OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, "HipoTrader_Panel_BG", OBJPROP_CORNER, CORNER_LEFT_UPPER);

   string labels[] = {"HipoTrader_Panel_Trend", "HipoTrader_Panel_HTF", "HipoTrader_Panel_MTF", "HipoTrader_Panel_Fibo", "HipoTrader_Panel_Status"};
   int y_positions[] = {105, 125, 145, 165, 185};
   
   for(int i = 0; i < ArraySize(labels); i++) {
      ObjectCreate(0, labels[i], OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, labels[i], OBJPROP_XDISTANCE, 15);
      ObjectSetInteger(0, labels[i], OBJPROP_YDISTANCE, y_positions[i]);
      ObjectSetInteger(0, labels[i], OBJPROP_ZORDER, 1);
      ObjectSetInteger(0, labels[i], OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, labels[i], OBJPROP_FONTSIZE, 10);
      ObjectSetString(0, labels[i], OBJPROP_FONT, "Arial");
      ObjectSetInteger(0, labels[i], OBJPROP_COLOR, clrWhite);
   }
   UpdateTraderPanel();
}


//+------------------------------------------------------------------+
//| تابع به‌روزرسانی پنل رابط کاربری (UpdateTraderPanel)            |
//+------------------------------------------------------------------+

void UpdateTraderPanel() {
   // نمایش خطا در صورت وجود
   if(lastError != "") {
      string error_text = "● خطا: " + lastError;
      ObjectSetString(0, "HipoTrader_Panel_Status", OBJPROP_TEXT, error_text);
      ObjectSetInteger(0, "HipoTrader_Panel_Status", OBJPROP_COLOR, clrRed);
      return;
   }

   // خط اول: روند کلی
   string trend_text = "● روند: ";
   color trend_color = clrGray;
   switch(currentTrend) {
      case TREND_UP: trend_text += "صعودی"; trend_color = clrGreen; break;
      case TREND_DOWN: trend_text += "نزولی"; trend_color = clrRed; break;
      case NEUTRAL: trend_text += "خنثی"; break;
   }
   ObjectSetString(0, "HipoTrader_Panel_Trend", OBJPROP_TEXT, trend_text);
   ObjectSetInteger(0, "HipoTrader_Panel_Trend", OBJPROP_COLOR, clrWhite);
   ObjectSetString(0, "HipoTrader_Panel_Trend", OBJPROP_TEXT, StringSubstr(trend_text, 2));
   ObjectSetString(0, "HipoTrader_Panel_Trend", OBJPROP_TEXT, "●");
   ObjectSetInteger(0, "HipoTrader_Panel_Trend", OBJPROP_COLOR, trend_color);
   ObjectSetInteger(0, "HipoTrader_Panel_Trend", OBJPROP_XDISTANCE, 15);
   ObjectSetString(0, "HipoTrader_Panel_Trend", OBJPROP_TEXT, trend_text);

   // خط دوم: HTF MACD
   string htf_text = "● HTF MACD: ";
   color htf_color = clrGray;
   double htf_main[], htf_signal[];
   if(CopyBuffer(macd_htf_handle, 0, 1, 1, htf_main) >= 1 && CopyBuffer(macd_htf_handle, 1, 1, 1, htf_signal) >= 1) {
      htf_text += (htf_main[0] > htf_signal[0]) ? "صعودی" : "نزولی";
      htf_color = (htf_main[0] > htf_signal[0]) ? clrGreen : clrRed;
   } else {
      htf_text += "نامشخص";
   }
   ObjectSetString(0, "HipoTrader_Panel_HTF", OBJPROP_TEXT, htf_text);
   ObjectSetInteger(0, "HipoTrader_Panel_HTF", OBJPROP_COLOR, clrWhite);
   ObjectSetString(0, "HipoTrader_Panel_HTF", OBJPROP_TEXT, StringSubstr(htf_text, 2));
   ObjectSetString(0, "HipoTrader_Panel_HTF", OBJPROP_TEXT, "●");
   ObjectSetInteger(0, "HipoTrader_Panel_HTF", OBJPROP_COLOR, htf_color);
   ObjectSetInteger(0, "HipoTrader_Panel_HTF", OBJPROP_XDISTANCE, 15);
   ObjectSetString(0, "HipoTrader_Panel_HTF", OBJPROP_TEXT, htf_text);

   // خط سوم: MTF MACD
   string mtf_text = "● MTF MACD: ";
   color mtf_color = clrGray;
   double mtf_main[], mtf_signal[];
   if(CopyBuffer(macd_mtf_handle, 0, 1, 1, mtf_main) >= 1 && CopyBuffer(macd_mtf_handle, 1, 1, 1, mtf_signal) >= 1) {
      mtf_text += (mtf_main[0] < 0) ? "صعودی" : "نزولی";
      mtf_color = (mtf_main[0] < 0) ? clrGreen : clrRed;
   } else {
      mtf_text += "نامشخص";
   }
   ObjectSetString(0, "HipoTrader_Panel_MTF", OBJPROP_TEXT, mtf_text);
   ObjectSetInteger(0, "HipoTrader_Panel_MTF", OBJPROP_COLOR, clrWhite);
   ObjectSetString(0, "HipoTrader_Panel_MTF", OBJPROP_TEXT, StringSubstr(mtf_text, 2));
   ObjectSetString(0, "HipoTrader_Panel_MTF", OBJPROP_TEXT, "●");
   ObjectSetInteger(0, "HipoTrader_Panel_MTF", OBJPROP_COLOR, mtf_color);
   ObjectSetInteger(0, "HipoTrader_Panel_MTF", OBJPROP_XDISTANCE, 15);
   ObjectSetString(0, "HipoTrader_Panel_MTF", OBJPROP_TEXT, mtf_text);

   // خط چهارم: وضعیت HipoFibo
   string fibo_text = "● HipoFibo: " + EnumToString(HipoFibo.GetCurrentStatus());
   color fibo_color = clrGray;
   if(HipoFibo.GetCurrentStatus() == ENTRY_ZONE_ACTIVE) fibo_color = clrGreen;
   else if(HipoFibo.GetCurrentStatus() == SEARCHING_FOR_LEG) fibo_color = clrGray;
   else fibo_color = clrYellow;
   ObjectSetString(0, "HipoTrader_Panel_Fibo", OBJPROP_TEXT, fibo_text);
   ObjectSetInteger(0, "HipoTrader_Panel_Fibo", OBJPROP_COLOR, clrWhite);
   ObjectSetString(0, "HipoTrader_Panel_Fibo", OBJPROP_TEXT, StringSubstr(fibo_text, 2));
   ObjectSetString(0, "HipoTrader_Panel_Fibo", OBJPROP_TEXT, "●");
   ObjectSetInteger(0, "HipoTrader_Panel_Fibo", OBJPROP_COLOR, fibo_color);
   ObjectSetInteger(0, "HipoTrader_Panel_Fibo", OBJPROP_XDISTANCE, 15);
   ObjectSetString(0, "HipoTrader_Panel_Fibo", OBJPROP_TEXT, fibo_text);

   // خط پنجم: وضعیت کلی
   string status_text = "● وضعیت: ";
   color status_color = clrGray;
   if(HipoFibo.IsEntryZoneActive()) {
      status_text += "ناحیه طلایی فعال";
      status_color = clrGreen;
   } else if(CountOpenTrades() > 0) {
      status_text += "معامله باز";
      status_color = clrYellow;
   } else {
      status_text += isCommandSent ? "در انتظار پاسخ کتابخانه" : "جستجوی سیگنال";
      status_color = isCommandSent ? clrYellow : clrGray;
   }
   ObjectSetString(0, "HipoTrader_Panel_Status", OBJPROP_TEXT, status_text);
   ObjectSetInteger(0, "HipoTrader_Panel_Status", OBJPROP_COLOR, clrWhite);
   ObjectSetString(0, "HipoTrader_Panel_Status", OBJPROP_TEXT, StringSubstr(status_text, 2));
   ObjectSetString(0, "HipoTrader_Panel_Status", OBJPROP_TEXT, "●");
   ObjectSetInteger(0, "HipoTrader_Panel_Status", OBJPROP_COLOR, status_color);
   ObjectSetInteger(0, "HipoTrader_Panel_Status", OBJPROP_XDISTANCE, 15);
   ObjectSetString(0, "HipoTrader_Panel_Status", OBJPROP_TEXT, status_text);
}

//+------------------------------------------------------------------+
//| تابع تبدیل رنگ به نام (GetColorName)                             |
//+------------------------------------------------------------------+

string GetColorName(color clr) {
   if(clr == clrGreen) return "سبز";
   if(clr == clrRed) return "قرمز";
   return "خاکستری";
};
