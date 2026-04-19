import { useState } from "react";
import { useNavigate } from "react-router-dom";
import { Button } from "../components/ui/button";
import { Input } from "../components/ui/input";
import { Label } from "../components/ui/label";
import { Card, CardContent, CardDescription, CardHeader } from "../components/ui/card";
import { AlertCircle } from "lucide-react";
import { useAuth } from "../lib/auth-context";

const Login = () => {
  const { login } = useAuth();
  const navigate = useNavigate();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);  //Add the missing loading state

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(""); // Clear previous errors
    setLoading(true); // Start loading

    try {
      // FIX 2: Ensure the login response is handled correctly
      const res = await login(email, password);

      if (!res?.success || !res.user) {
        setError(res?.message || "An unexpected error occurred");
      } else {
        const role = res.user.role;
        if (role === "admin") navigate("/admin");
        else if (role === "retailer") navigate("/dashboard");
        else if (role === "warehouse_manager") navigate("/warehouse");
        else if (role === "3pl_manager") navigate("/logistics");
        else if (role === "driver") navigate("/driver");
        else navigate("/");
      }
    } catch (err: any) {
      setError("Failed to connect to the server.");
    } finally {
      setLoading(false); // Stop loading regardless of outcome
    }
  };

  return (
    <div className="min-h-screen flex items-center justify-center bg-white px-4">
      <div className="w-full max-w-md space-y-8">
        <div className="flex flex-col items-center gap-3">
        </div>

        <Card className="border-border shadow-lg">
          <CardHeader className="space-y-1 pb-4">
            <img src="/logo.png" alt="Nestlé Logo" className="mx-auto mb-4 h-24 w-24" />
            <h2 className="text-3xl font-semibold text-center text-gray-900">Sign In to Your Account</h2>
            <CardDescription className="text-center">
              Enter your credentials to access the dashboard.
            </CardDescription>
          </CardHeader>
          <CardContent>
            <form onSubmit={handleSubmit} className="space-y-8">
              {error && (
                <div className="flex items-center gap-2 rounded-lg border border-destructive/30 bg-destructive/10 p-3 text-sm text-destructive">
                  <AlertCircle className="h-4 w-4 shrink-0" />
                  {error}
                </div>
              )}

              <div className="space-y-2">
                <Label htmlFor="email">Email</Label>
                <Input
                  id="email"
                  type="email"
                  placeholder="retailer@demo.com"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  required
                />
              </div>

              <div className="space-y-2">
                <Label htmlFor="password">Password</Label>
                <Input
                  id="password"
                  type="password"
                  placeholder="••••••••••••"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  required
                />
              </div>

              <Button type="submit" className="w-full rounded-2xl bg-[#0a3c75] px-4 py-3 text-white font-semibold hover:bg-[#082c56]" disabled={loading}>
                {loading ? "Signing in..." : "Sign in"}
              </Button>
            </form>
          </CardContent>
        </Card>
      </div>
    </div>
  );
}

export default Login;