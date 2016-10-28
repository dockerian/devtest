/*
 * JCloudsSettings.java: JClouds Settings for openstack
 *
 * (C) 2015 Hewlett-Packard Development Company, L.P.
 * Jason (Yuxin) Zhu
 *
 */

public class JCloudsSettings {

  public static final String OS_AUTH_URL =
    System.getenv("OS_AUTH_URL") != null ?
    System.getenv("OS_AUTH_URL") : "https://10.23.71.11:5000/v2.0/";

  public static final String OS_PASSWORD =
    System.getenv("OS_PASSWORD") != null ?
    System.getenv("OS_PASSWORD") : "1234567890123456789012345678901234567890";

  public static final String OS_USERNAME =
    System.getenv("OS_USERNAME") != null ?
    System.getenv("OS_USERNAME") : "admin";

  public static final String OS_TENANT_NAME =
    System.getenv("OS_TENANT_NAME") != null ?
    System.getenv("OS_TENANT_NAME") : "admin";
}
