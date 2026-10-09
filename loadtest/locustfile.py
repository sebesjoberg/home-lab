from locust import HttpUser, task, between

class KubernetesClusterTest(HttpUser):
    # Vänta mellan 0.5 till 2 sekunder mellan varje klick/request per virtuell användare
    wait_time = between(0.5, 2.0)

    @task(3)
    def test_traefik_and_authentik(self):
        """Testar Authentik (Högsta prioritet/vikt då Authentik drar mest CPU)"""
        headers = {"Host": "auth.lab.home"}
        # Vi antar att /-routen ger en login-sida (GET)
        self.client.get("/", headers=headers, name="Authentik - Login Page")

    @task(2)
    def test_argocd(self):
        """Testar ArgoCD-gränssnittet"""
        headers = {"Host": "argocd.lab.home"}
        self.client.get("/", headers=headers, name="ArgoCD - UI")

    @task(1)
    def test_openbao(self):
        """Testar OpenBao/Vault-gränssnittet"""
        headers = {"Host": "bao.lab.home"}
        self.client.get("/", headers=headers, name="OpenBao - UI")
