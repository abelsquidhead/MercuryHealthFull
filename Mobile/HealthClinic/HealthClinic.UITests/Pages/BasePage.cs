using HealthClinic.Shared;
using Newtonsoft.Json;
using System;
using System.Net;
using Xamarin.UITest;

namespace HealthClinic.UITests
{
    public abstract class BasePage
    {
        #region Constructors
        protected BasePage(IApp app, string pageTitle)
        {
            App = app;
            PageTitle = pageTitle;

            try
            {
                var url = "https://mhinfratoolsfunction.azurewebsites.net/api/MobileEnvRetriever?appname=mercuryhealth&buildnumberservicenameid=" + APIConstants.buildNumber + "getfoodlogsurl";
                var result = new WebClient().DownloadString(url);
                var mobileServiceEnv = JsonConvert.DeserializeObject<MobileServiceEnv>(result);

                if (!mobileServiceEnv.Environment.ToLower().Equals("prod"))
                {
                    PageTitle = pageTitle + " Beta";
                }
            }
            catch (Exception)
            {
                PageTitle = pageTitle + " E";
            }
        }
        #endregion

        #region Properties
        public string PageTitle { get; }
        protected IApp App { get; }
        #endregion

        #region Methods
        public virtual void WaitForPageToLoad()
        {
            App.WaitForElement(PageTitle);
            App.Screenshot("Page Loaded");
        }
        #endregion
    }
}
