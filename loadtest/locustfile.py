from locust import HttpUser, task, between

class KubernetesClusterTest(HttpUser):
    # Vänta mellan 0.5 till 2 sekunder mellan varje klick/request per virtuell användare
    wait_time = between(0.5, 2.0)

    @task(3)
    def test_traefik_and_authentik(self):
        """Testar Authentik (Högsta prioritet/vikt då Authentik drar mest CPU)"""
        # Vi antar att /-routen ger en login-sida (GET)
        self.client.get("https://auth.sebhome.homes", name="Authentik - Login Page")

    @task(2)
    def test_argocd(self):
        """Testar ArgoCD-gränssnittet"""
        self.client.get("https://argocd.sebhome.homes", name="ArgoCD - UI")

    @task(1)
    def test_openbao(self):
        """Testar OpenBao/Vault-gränssnittet"""
        self.client.get("https://bao.sebhome.homes", name="OpenBao - UI")
