# CI/CD Pipeline Setup Guide

This guide will help you set up the automated CI/CD pipeline for your Flutter web app.

## Overview

The CI/CD pipeline will:
- Build your Flutter web app when you push to the `master` branch
- Deploy it to Firebase Hosting
- Send email and Discord notifications for build success, deployment success, and failures

## Prerequisites

1. Your Flutter project is pushed to a GitHub repository
2. You have admin access to the repository

## Setup Steps

### 1. Firebase Project Setup

1. Make sure you have a Firebase project set up
2. Ensure Firebase Hosting is enabled in your project
3. Your project should already be configured for manual deployment

### 2. Configure GitHub Secrets

You need to add the following secrets to your repository:

1. Go to your repository on GitHub
2. Navigate to **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret** and add:

#### Gmail App Password (`GMAIL_APP_PASSWORD`)
1. Go to your Google Account settings
2. Navigate to **Security** → **2-Step Verification** → **App passwords**
3. Generate a new app password for "Mail"
4. Copy the generated password and add it as `GMAIL_APP_PASSWORD`

#### Discord Webhook URL (`DISCORD_WEBHOOK_URL`)
1. Go to your Discord server
2. Navigate to **Server Settings** → **Integrations** → **Webhooks**
3. Create a new webhook
4. Copy the webhook URL and add it as `DISCORD_WEBHOOK_URL`

#### Firebase Service Account (`FIREBASE_SERVICE_ACCOUNT`)
1. Go to your Firebase Console
2. Navigate to **Project Settings** → **Service accounts**
3. Click **Generate new private key**
4. Download the JSON file
5. Copy the entire JSON content and add it as `FIREBASE_SERVICE_ACCOUNT`

#### Firebase Project ID (`FIREBASE_PROJECT_ID`)
1. Go to your Firebase Console
2. Copy your Project ID from the project overview
3. Add it as `FIREBASE_PROJECT_ID`

### 3. Repository Settings

Make sure your repository has the following settings:

1. **Actions permissions**: Go to **Settings** → **Actions** → **General**
   - Ensure "Allow all actions and reusable workflows" is selected
   - Check "Read and write permissions" under "Workflow permissions"

2. **Pages permissions**: Go to **Settings** → **Actions** → **General**
   - Under "Workflow permissions", ensure "Read and write permissions" is selected

## How It Works

### Trigger
- The pipeline triggers automatically when you push to the `master` branch

### Build Process
1. **Checkout**: Clones your repository
2. **Setup Flutter**: Installs Flutter 3.24.0
3. **Dependencies**: Runs `flutter pub get`
4. **Build**: Builds the web app with `flutter build web --release`

### Deployment
- Deploys the built web app to Firebase Hosting
- Your app will be available at: `https://your-project-id.web.app/`

### Notifications
- **Build Success**: Email and Discord notification when build completes successfully
- **Deployment Success**: Email and Discord notification when deployment to GitHub Pages is successful
- **Failure**: Email and Discord notification if build or deployment fails

## Customization

### Email Configuration
- Update the email address in the workflow file (`amansingh08088@gmail.com`)
- Modify the email templates in the workflow file

### Discord Configuration
- Update the Discord webhook URL in your repository secrets
- Modify the Discord message format in the workflow file

### Flutter Version
- Change the Flutter version in the workflow file if needed:
  ```yaml
  flutter-version: '3.24.0'
  ```

## Troubleshooting

### Common Issues

1. **Build fails with dependency errors**
   - Check your `pubspec.yaml` file for any dependency issues
   - Run `flutter pub get` locally to verify dependencies

2. **Deployment fails**
   - Ensure Firebase Hosting is enabled in your Firebase project
   - Verify your Firebase service account has the correct permissions
   - Check that your Firebase project ID is correct

3. **Email notifications not working**
   - Verify your Gmail app password is correct
   - Check that 2-factor authentication is enabled on your Google account

4. **Discord notifications not working**
   - Verify your Discord webhook URL is correct
   - Check that the webhook is still active in your Discord server

### Manual Trigger

You can manually trigger the workflow:
1. Go to **Actions** tab in your repository
2. Select the "Flutter Web CI/CD" workflow
3. Click **Run workflow**
4. Select the branch and click **Run workflow**

## Security Notes

- Never commit sensitive information like passwords or API keys directly to your repository
- Always use GitHub Secrets for sensitive data
- Regularly rotate your Gmail app password and Discord webhook URLs

## Support

If you encounter any issues:
1. Check the Actions tab in your repository for detailed logs
2. Review the troubleshooting section above
3. Check GitHub's documentation for Actions and Pages 