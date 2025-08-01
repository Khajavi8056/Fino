//+------------------------------------------------------------------+
//|                                          HipoSignalDecker.mqh    |
//|                                     محصولی از: Hipo Algorithm      |
//|                                           نسخه: ۱.۰.۰              |
//|                  لایه مدیریت و ایجاد ساختارهای فیبوناچی             |
//+------------------------------------------------------------------+

#ifndef HIPO_SIGNAL_DECKER_MQH
#define HIPO_SIGNAL_DECKER_MQH

#include <HipoFibonacci.mqh> // برای دسترسی به توابع فیبو

// وضعیت ساختار از دید این کلاس
enum ENUM_DECKER_STATUS
{
    DECKER_IDLE,             // بیکار، به دنبال سیگنال برای ساخت
    DECKER_STRUCTURE_ACTIVE  // ساختار ایجاد شده و منتظر اکسپرت است
};

//+------------------------------------------------------------------+
//| کلاس CHipoSignalDecker                                          |
//+------------------------------------------------------------------+
class CHipoSignalDecker
{
private:
    // --- هندل‌ها و تنظیمات ---
    int                 m_htf_macd_handle;
    ENUM_TIMEFRAMES     m_htf;
    
    // --- متغیرهای وضعیت ---
    ENUM_DECKER_STATUS  m_status;
    ENUM_DIRECTION      m_active_direction;
    datetime            m_structure_creation_time;
    
    // --- متد خصوصی برای لاگ ---
    void Log(string message)
    {
        Print("SignalDecker: ", message);
    }

public:
    // --- سازنده ---
    CHipoSignalDecker()
    {
        m_htf_macd_handle = INVALID_HANDLE;
        m_status = DECKER_IDLE;
        m_structure_creation_time = 0;
        m_active_direction = LONG; // مقدار اولیه
    }

    // --- راه‌اندازی ---
    bool Initialize(ENUM_TIMEFRAMES htf, int htf_fast_ema, int htf_slow_ema, int htf_signal)
    {
        m_htf = htf;
        m_htf_macd_handle = iMACD(_Symbol, m_htf, htf_fast_ema, htf_slow_ema, htf_signal, PRICE_CLOSE);
        if(m_htf_macd_handle == INVALID_HANDLE)
        {
            Log("خطا در ایجاد هندل مکدی HTF");
            return false;
        }
        m_status = DECKER_IDLE;
        Log("با موفقیت راه‌اندازی شد.");
        return true;
    }
    
    // --- توقف ---
    void Deinitialize()
    {
        if(m_htf_macd_handle != INVALID_HANDLE)
        {
            IndicatorRelease(m_htf_macd_handle);
        }
        Log("متوقف شد.");
    }

    // --- تابع اصلی که در کندل جدید HTF فراخوانی می‌شود ---
    void OnNewHtfCandle(ENUM_MACD_BIAS htf_bias)
    {
        // اگر ساختاری از قبل فعال است، کاری نکن
        if(m_status == DECKER_STRUCTURE_ACTIVE)
        {
            // تایم‌اوت برای جلوگیری از قفل شدن: اگر اکسپرت ساختار را تحویل نگرفت، آن را حذف می‌کنیم
            if(TimeCurrent() - m_structure_creation_time > PeriodSeconds(m_htf) * 5)
            {
                 Log("ساختار برای مدت طولانی معلق مانده است. حذف می‌شود.");
                 HFiboStopCurrentStructure();
                 Reset();
            }
            return;
        }

        // اگر در حالت بیکار هستیم، به دنبال سیگنال می‌گردیم
        if(m_status == DECKER_IDLE)
        {
            if(htf_bias == MACD_BULLISH || htf_bias == MACD_BEARISH)
            {
                ENUM_DIRECTION direction = (htf_bias == MACD_BULLISH) ? LONG : SHORT;
                Log("شرایط مکدی برای ساختار " + EnumToString(direction) + " فراهم است. ارسال دستور ساخت با چراغ خاموش...");

                // 1. چراغ‌ها خاموش (اطمینان از خاموش بودن)
                HFiboSetVisibility(false);
                
                // 2. ارسال دستور ساخت
                if(HFiboCreateNewStructure(direction))
                {
                    Log("دستور ساخت با موفقیت ارسال شد. وضعیت به فعال تغییر می‌کند.");
                    m_status = DECKER_STRUCTURE_ACTIVE;
                    m_active_direction = direction;
                    m_structure_creation_time = TimeCurrent();
                }
                else
                {
                    Log("خطا در ارسال دستور ساخت به کتابخانه فیبوناچی.");
                }
            }
        }
    }
    
    // --- توابعی برای ارتباط با لایه دوم (CHipoFino) ---
    ENUM_DECKER_STATUS GetStatus()
    {
        return m_status;
    }
    
    ENUM_DIRECTION GetActiveDirection()
    {
        return m_active_direction;
    }
    
    // --- ریست کردن وضعیت (وقتی اکسپرت کارش با ساختار تمام می‌شود) ---
    void Reset()
    {
        if(m_status == DECKER_STRUCTURE_ACTIVE)
        {
            Log("وضعیت ریست شد. بازگشت به حالت بیکار برای شکار موقعیت جدید.");
        }
        m_status = DECKER_IDLE;
        m_structure_creation_time = 0;
    }
};

#endif
