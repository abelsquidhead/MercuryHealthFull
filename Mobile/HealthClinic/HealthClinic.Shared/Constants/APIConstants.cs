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
                return "";
            }
        }
    }
}
