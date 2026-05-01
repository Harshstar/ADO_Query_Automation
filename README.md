# Azure DevOps WIQL Reporter

This repository contains an automated solution to query Azure DevOps work items across multiple projects using WIQL and export the results into CSV files using PowerShell and Azure DevOps pipelines.

---

## 📁 Project Structure

```
ADO_Query_Automation/
│
├── Workitem_Scripts/
│   └── list_query.ps1
│
└── pipeline/
    ├── get-workitems.yml
    └── get-QueryVariable.yml
```

---

## 🚀 Features

* Execute WIQL queries across multiple Azure DevOps projects
* Filter work items based on:

  * Tags
  * Date range (Closed Date)
  * Work item types (Bug, Task, PBI)
* Extract parent-child relationships
* Export:

  * Project-wise CSV files
  * Combined merged CSV file
* Fully automated using Azure DevOps pipeline
* Secure handling of sensitive data using pipeline variables

---

## ⚙️ How It Works

1. **Pipeline (`get-workitems.yml`)**

   * Triggers PowerShell script execution
   * Passes required variables (organization, tags, date range, project list)

2. **Variables (`get-QueryVariable.yml`)**

   * Stores configurable values like:

     * Organization name
     * Tags
     * Project list
     * Script path

3. **PowerShell Script (`list_query.ps1`)**

   * Executes WIQL query
   * Fetches work item details in batches
   * Extracts required fields
   * Generates CSV outputs

---

## 🧾 Required Inputs

| Parameter    | Description                                        |
| ------------ | -------------------------------------------------- |
| organization | Azure DevOps organization name (sample value used) |
| pat          | Personal Access Token (secure pipeline variable)   |
| startDate    | Start date for filtering closed work items         |
| endDate      | End date for filtering closed work items           |
| tags         | Comma-separated tags (sample values used)          |
| projectList  | Comma-separated project names (sample values used) |

---

## 🔐 Authentication & Security

* Uses **Personal Access Token (PAT)** for authentication
* PAT is stored as a **secure pipeline variable**, ensuring:

  * Value is masked
  * Cannot be viewed after creation
* `startDate` and `endDate` are configured via pipeline variables for flexibility

---

## ▶️ Usage

1. Clone the repository

2. Configure variables in:

   ```
   pipeline/get-QueryVariable.yml
   ```

   Example:

   ```
   organization: 'Demo'
   tags: 'L3,AD'
   projectList: 'Project1,Project2'
   ```

   > ℹ️ `Demo`, `L3, AD`, `Project1`, and `Project2` are sample placeholders. Replace them with your actual Azure DevOps organization, tags, and project names.

3. Add pipeline variables:

   * `pat` (mark as secret)
   * `startDate`
   * `endDate`

4. Run the pipeline manually

---

## 📊 Output

* Individual CSV per project
* Combined CSV file:

  ```
  AllProjects_Merged.csv
  ```
* Published as pipeline artifact

---

## 📌 Notes

* Pipeline is set with `trigger: none` (manual execution)
* Supports both:

  * Local execution
  * Azure DevOps pipeline execution

---

## 🛠️ Tech Stack

* PowerShell
* Azure DevOps Pipelines
* WIQL (Work Item Query Language)

---

## 📄 License

This project is for internal automation and reporting purposes.
