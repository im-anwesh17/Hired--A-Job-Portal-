# 🚀 Hirrd - Full Stack Job Portal

**Hirrd** is a modern, responsive, and full-stack job portal application designed to connect job seekers with employers. Built with a powerful stack of modern web technologies, Hirrd offers a seamless experience for browsing job listings, managing applications, and posting new opportunities.

## ✨ Features

- **User Authentication:** Secure authentication and user management using **Clerk**.
- **Role-Based Access Control:** Distinct experiences for **Job Seekers** and **Employers/Recruiters**.
- **Job Discovery & Filtering:** Interactive job boards with advanced filtering (by location, role, etc.).
- **Application Management:** Track applied jobs and manage received applications effortlessly.
- **Modern UI:** A stunning, dark-mode first interface built with **Tailwind CSS** and **Shadcn UI**.
- **Real-Time Backend:** Blazing-fast data storage and retrieval via **Supabase**.

## 🛠️ Tech Stack

- **Frontend:** React (Vite), React Router v6
- **Styling:** Tailwind CSS, Shadcn UI, Embla Carousel
- **Authentication:** Clerk
- **Backend/Database:** Supabase
- **Hosting:** Vercel

## 🚀 Getting Started

### Prerequisites

Make sure you have [Node.js](https://nodejs.org/) installed on your machine. We recommend using `yarn` as the package manager for this project.

### Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/im-anwesh17/Hired--A-Job-Portal-.git
   cd Hired--A-Job-Portal-
   ```

2. **Install dependencies:**
   ```bash
   yarn install
   ```

3. **Set up Environment Variables:**
   Create a `.env.local` file in the root of the project and add your required keys:
   ```env
   VITE_CLERK_PUBLISHABLE_KEY=your_clerk_publishable_key
   VITE_SUPABASE_URL=your_supabase_url
   VITE_SUPABASE_ANON_KEY=your_supabase_anon_key
   ```

4. **Run the development server:**
   ```bash
   yarn dev
   ```
   The app will be running at `http://localhost:5173`.

## 🚢 Deployment

The project is configured for automated deployment to **Vercel** with custom deployment scripts designed to validate your build and sync environment variables automatically.

To deploy the application, simply run the cross-platform deployment script:

```bash
node deploy.js
```
*Alternatively, Windows users can use the PowerShell version: `.\deploy.ps1`*

## 🤝 Contributing

Contributions, issues, and feature requests are welcome! Feel free to check the issues page if you want to contribute.

## 📝 License

This project is open-source and available for free use.
