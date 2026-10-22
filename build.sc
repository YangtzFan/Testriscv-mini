import mill._, scalalib._

object riscvMini extends ScalaModule {
  def scalaVersion = "2.13.7"
  def chiselVersion = "6.2.0"

  def sources = T.sources {
    millSourcePath / os.up / "riscv-mini" / "src" / "main" / "scala"
  }

  def ivyDeps = Agg(ivy"org.chipsalliance::chisel:${chiselVersion}")
  def scalacPluginIvyDeps = Agg(
    ivy"org.chipsalliance:::chisel-plugin:${chiselVersion}"
  )
  def scalacOptions = Seq(
    "-language:reflectiveCalls",
    "-deprecation",
    "-feature",
    "-Xcheckinit"
  )
}
