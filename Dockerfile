# Defines the multi-stage Docker build for your React application

# Use the official NGINX image
FROM public.ecr.aws/nginx/nginx:alpine

# Copy static site to NGINX public directory
COPY dist/ /usr/share/nginx/html

# Expose port 80
EXPOSE 80

# Start NGINX
CMD ["nginx", "-g", "daemon off;"]

