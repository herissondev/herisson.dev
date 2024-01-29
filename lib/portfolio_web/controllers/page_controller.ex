defmodule PortfolioWeb.PageController do
  use PortfolioWeb, :controller

  def home(conn, _params) do
    # The home page is often custom made,
    # so skip the default app layout.
    render(conn, :home, layout: false, cv: cv_data(), page_title: "Aimé Risson")
  end

  defp cv_data do
    %{
      name: "Aimé RISSON",
      social: %{
        phone: "+33781517932",
        email: "aime.risson.1@gmail.com",
        github_link: "https://github.com/herissondev/",
        linkedin_link: "https://www.linkedin.com/in/aime-risson/"
      },
      about: "J'aime bien l'informatique ouais ouais",
      location: "Lyon, France",
      summary:
        "Passionné par l’informatique, je suis en permanence à la recherche de défis techniques et variés pour approfondir mes connaissances et me former aux meilleures pratiques de développement. Je suis également profondément intéressé par la maîtrise de la chaîne de développement complète, de la conception au déploiement, en passant par les outils DevOps, l’intégration et le déploiement continus (CI/CD), les tests automatisés, Docker et Kubernetes.",
      experiences: [
        %{
          title: "Application Métier Industriel - CloudFlow",
          job_title: "Développement Full Stack",
          date: "2022 - 2023",
          skills: ["Django", "CI/CD", "Next.js", "Kubernetes", "Docker", "Tests", "Monorepo"],
          description: "",
          summary:
            "Conception, réalisation et vente d’une application de planification de maintenance industrielle. \n Réalisation du backend et frontend."
        },
        %{
          title: "Développement d'un interpréteur - Archethic",
          job_title: "Stage Développement Backend",
          link: "https://github.com/archethic-foundation/archethic-node",
          date: "Juillet 2023",
          skills: ["Elixir", "GIT", "RPC", "Tests", "Agile"],
          description: "",
          summary:
            "Stage obtenu suite à des contributions open source dans le projet blockchain Archethic. Manipulation d’AST (Abstract Syntax Tree) en Elixir : enrichissement d’un langage interprété maison."
        }
      ],
      formations: [
        %{
          title: "BUT informatique - IUT Lyon 1",
          job_title: nil,
          date: "2022 - 2025",
          skills: [],
          description: "",
          summary: ""
        },
        %{
          title: "Baccalauréat Mathématiques - Informatique",
          job_title: "Mention Très Bien",
          date: "2022",
          skills: [],
          description: "",
          summary: ""
        }
      ],
      projects: [
        %{
          title: "herisson.dev",
          description: "Mon site personnel et blog. Fait avec Elixir & Phoenix",
          tags: ["Open Source", "Elixir", "Phoenix"],
          link: "https://herisson.dev"
        },
        %{
          title: "Vitalert - SAAS",
          description:
            "Vente d’un service en ligne pour notifications Vinted. Jusqu’à 20 utilisateurs payants.",
          tags: ["AWS Cognito", "AWS Lambda", "Kubernetes", "Docker", "FastApi"]
        },
        %{
          title: "Vinted Api Wrapper",
          description:
            "Un package Python facilitant l'accès à l'API Vinted pour rechercher de nouvelles annonces.",
          tags: ["Open Source", "Python", "PyPi"],
          link: "https://github.com/herissondev/vinted-api-wrapper"
        },
        %{
          title: "Vinted Wrapper",
          description:
            "Un package Python facilitant l'accès à l'API  je suce des bites toutes la journée si tu veux je peux te sucer elouan Vinted pour rechercher de nouvelles annonces.",
          tags: ["Open Source", "Python", "PyPi"]
        },
        %{
          title: "Vinted Wrapper",
          description:
            "Un package Python facilitant l'accès à l'API Vinted pour rechercher de nouvelles annonces.",
          tags: ["Open Source", "Python", "PyPi"]
        }
      ]
    }
  end
end
