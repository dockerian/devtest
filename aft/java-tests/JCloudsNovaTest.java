/*
 * JCloudsNovaTest.java: JClouds Nova Test for openstack
 *
 * (C) 2015 Hewlett-Packard Development Company, L.P.
 * Jason (Yuxin) Zhu
 *
 */

import com.google.common.collect.ImmutableSet;
import com.google.common.io.Closeables;
import com.google.inject.Module;
import org.jclouds.ContextBuilder;
import org.jclouds.logging.slf4j.config.SLF4JLoggingModule;
import org.jclouds.openstack.nova.v2_0.NovaApi;
import org.jclouds.openstack.nova.v2_0.domain.Server;
import org.jclouds.openstack.nova.v2_0.features.ServerApi;

import java.io.Closeable;
import java.io.IOException;
import java.util.Set;

public class JCloudsNovaTest implements Closeable {
    private final NovaApi novaApi;
    private final Set<String> regions;

    public static void main(String[] args) throws IOException, Exception {
        JCloudsNovaTest jcloudsNova = new JCloudsNovaTest();

        try {
            jcloudsNova.listServers();
            jcloudsNova.close();
        } catch (Exception e) {
            e.printStackTrace();
        } finally {
            jcloudsNova.close();
        }
    }

    public JCloudsNovaTest() throws Exception {
        JCloudsUtils.EnableTrustAllCerts();

        Iterable<Module> modules = ImmutableSet.<Module>of(new SLF4JLoggingModule());

        String provider = "openstack-nova";
        String identity = JCloudsSettings.OS_TENANT_NAME + ":" + JCloudsSettings.OS_USERNAME; // tenantName:userName
        String credential = JCloudsSettings.OS_PASSWORD;
        String endpoint = JCloudsSettings.OS_AUTH_URL;

        novaApi = ContextBuilder.newBuilder(provider)
                .endpoint(endpoint)
                .credentials(identity, credential)
                .modules(modules)
                .buildApi(NovaApi.class);
        regions = novaApi.getConfiguredRegions();
    }

    private void listServers() {
        for (String region : regions) {
            ServerApi serverApi = novaApi.getServerApi(region);

            System.out.println("Servers in " + region);

            for (Server server : serverApi.listInDetail().concat()) {
                System.out.println("  " + server);
            }
        }
    }

    public void close() throws IOException {
        Closeables.close(novaApi, true);
    }
}
