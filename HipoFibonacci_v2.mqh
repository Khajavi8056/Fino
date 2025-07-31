ننت   }


   void StopCurrentStructure()
   {
      for(int i = ArraySize(m_families) - 1; i >= 0; i--)
      {
         if(m_families[i] != NULL)
         {
            m_families[i].Destroy();
            delete m_families[i];
            m_families[i] = NULL;
            Log("دستور توقف از اکسپرت دریافت و ساختار فعال متوقف شد.");
         }
      }
      ArrayResize(m_families, 0);
   }
int GetActiveFamiliesCount()
   {
      return ArraySize(m_families);
   }
};

//+------------------------------------------------------------------+
//| متغیرهای سراسری                                                |
//+------------------------------------------------------------------+
CStructureManager* g_manager = NULL;

//+------------------------------------------------------------------+
//| توابع سراسری برای استفاده در اکسپرت                           |
//+------------------------------------------------------------------+
bool HFiboOnInit()
{
   g_manager = new CStructureManager();
   if(g_manager == NULL)
   {
      Print("خطا: نمی‌توان CStructureManager را ایجاد کرد");
      return false;
   }
   return g_manager.HFiboOnInit();
}

void HFiboOnDeinit(const int reason)
{
   if(g_manager != NULL)
   {
      g_manager.HFiboOnDeinit(reason);
      delete g_manager;
      g_manager = NULL;
   }
}

void HFiboOnTick()
{
   if(g_manager != NULL)
      g_manager.HFiboOnTick();
}

void HFiboOnNewBar()
{
   if(g_manager != NULL)
      g_manager.HFiboOnNewBar();
}

SSignal HFiboGetSignal()
{
   if(g_manager != NULL)
      return g_manager.GetSignal();
   SSignal signal = {"", ""};
   return signal;
}

bool HFiboAcknowledgeSignal(string id)
{
   if(g_manager != NULL)
      return g_manager.AcknowledgeSignal(id);
   return false;
}

void HFiboOnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   if(g_manager != NULL)
      g_manager.HFiboOnChartEvent(id, lparam, dparam, sparam);
}

bool HFiboCreateNewStructure(ENUM_DIRECTION direction)
{
   if(g_manager != NULL)
      return g_manager.CreateNewStructure(direction);
   return false;
}


// این تابع جدید رو به انتهای فایل، کنار بقیه توابع HFibo اضافه کن

double HFiboGetMotherZeroPoint()
{
   if(g_manager != NULL)
      return g_manager.GetMotherZeroPoint();
   return 0.0;
}
void HFiboStopCurrentStructure()
{
   if(g_manager != NULL)
      g_manager.StopCurrentStructure();
}
bool HFiboIsStructureBroken()
{
   if(g_manager != NULL && g_manager.GetActiveFamiliesCount() == 0)
   {
      return true; // هیچ ساختاری فعال نیست، یعنی ساختار تخریب شده
   }
   return false; // ساختار همچنان فعال است
}


//تابع نهایی برای دسترسی عمومی به آخرین داده‌های رویداد فیبوناچی -->>
SFibonacciEventData HFiboGetLastEventData()
{
   if(g_manager != NULL)
   {
      return g_manager.GetActiveFamilyEventData();
   }
   
   // اگر مدیر اصلی وجود نداشت، ساختار خالی برمیگردانیم
   SFibonacciEventData empty_data;
   return empty_data;
}
موم
