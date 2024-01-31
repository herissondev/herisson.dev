defmodule PortfolioWeb.PageController do
  use PortfolioWeb, :controller

  def home(conn, _params) do
    # The home page is often custom made,
    # so skip the default app layout.
    render(conn, :home, cv: cv_data(), page_title: "Aimé Risson")
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
      about: "Développeur informatique en devenir ! Passionné par les nouvelles technologies, j'aspire à maitriser la chaine de développement complète.",
      location: "Lyon, France",
      summary:
        "Actuellement en BUT Informatique à l'IUT Lyon 1, je suis à la recherche d'un stage de 2 mois en développement backend.",
      experiences: [
        %{
          title: "Développement d'un interpréteur - Archethic",
          job_title: "Stage Développement Backend",
          link: "https://github.com/archethic-foundation/archethic-node",
          date: "Juillet 2023",
          skills: ["Elixir", "GIT", "RPC", "Tests", "Agile"],
          description: "",
          summary:
            "Stage obtenu suite à des contributions open source dans le projet blockchain Archethic. Manipulation d’AST (Abstract Syntax Tree) en Elixir : enrichissement d’un langage interprété maison."
        },
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
          title: "Refactoring Javascript  vers Typescript - Archethic",
          job_title: "Stage Développement",
          link: "https://github.com/archethic-foundation/",
          date: "Avril 2023",
          skills: ["Typescript","Javascript", "CI/CD","Agile"],
          description: "",
          summary:
            "Stage obtenu suite à des contributions open source dans le projet blockchain Archethic. Refactoring d'un SDK Javascript vers un SDK Typescript."
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
          title: "CloudFlow",
          description: "Création d'une entreprise pour vendre des logiciels de gestion industrielle.",
          tags: ["Monorepo", "Kubernetes", "Django", "Next.js"],
        },
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
          title: "AEweb Github Action",
          link: "https://github.com/archethic-foundation/aeweb-github-action",
          description:
            "Développement d'une Action Github permettant d'héberger facilement un site web sur la blockchain Archethic",
          tags: ["Open Source", "Github Action", "Javascript"]
        },
        %{
          title: "Serrata",
          link: "https://serrata.super-sympa.fr/",
          description:
            "Jeu de tapage de clavier sur les drapeaux du monde. Fait entre amis !",
          tags: ["Open Source", "React", "ExpressJS"]
        }
      ]
    }
  end
end
