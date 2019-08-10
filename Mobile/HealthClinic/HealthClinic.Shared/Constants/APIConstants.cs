using Newtonsoft.Json;
using System;
using System.Net;

namespace HealthClinic.Shared
{
    public static class APIConstants
    {
        public const string GetFoodLogsUrl = "https://mercuryhealth-dev.azurewebsites.net/api/FoodLogApi";
        public const string PostFoodUrl = "https://abelmercuryhealthservice-dev.azurewebsites.net/ImageIDAPI/UploadFoodImage1";
        public const string DeleteFoodLogUrl = "https://abelmercuryhealthservice-dev.azurewebsites.net/FoodApi/DeleteFoodItem";

        public static string buildNumber = "__Build_BuildNumber__";

        public static string GetTheFoodLogsUrl
        {

            get
            {
                string url = "https://mhinfratoolsfunction.azurewebsites.net/api/MobileEnvRetriever?appname=mercuryhealth&buildnumberservicenameid=" + buildNumber + "getfoodlogsurl";
                string result1 = new WebClient().DownloadString(url);
                var deserializedObj = JsonConvert.DeserializeObject<MobileServiceEnv>(result1);

                return deserializedObj.Url;
            }
        }

        public static string GetServiceEnvironmentIcon
        {
            get
            {
                string url = "https://mhinfratoolsfunction.azurewebsites.net/api/MobileEnvRetriever?appname=mercuryhealth&buildnumberservicenameid=" + buildNumber + "getfoodlogsurl";
                string result1 = new WebClient().DownloadString(url);
                var mobileServiceEnv = JsonConvert.DeserializeObject<MobileServiceEnv>(result1);

                if (mobileServiceEnv.EnvironmentName.ToLower().Equals("beta"))
                {
                    return " B";
                }
                else
                {
                    return "";
                }
            }
        }
    }

    public class MobileServiceEnv
    {
        public string EnvironmentName { get; set; }
        public string Url { get; set; }
        public string PartitionKey { get; set; }
        public string RowKey { get; set; }
        public DateTime TimeStamp { get; set; }
        public string Etag { get; set; }
    }
}
